package main

import "core:text/match"
import "core:unicode/utf8"
import "core:io"
import "core:os"
import "core:sys/posix"
import "core:fmt"

CURSOR_PREFIX :: "$"
CURSOR_PREFIX_OFFSET :: 2

orig_mode : posix.termios

enable_raw_mode :: proc() {
    res := posix.tcgetattr(posix.STDIN_FILENO, &orig_mode)
    if res == .FAIL {
        return
    }

    posix.atexit(disable_raw_mode)

    raw := orig_mode
    raw.c_lflag -= {.ECHO, .ICANON}
    res = posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw)

    if res == .FAIL {
        return
    }
}

disable_raw_mode :: proc "c" () {
    posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &orig_mode)
}

print_cursor :: proc() {
    fmt.printf("%s ", CURSOR_PREFIX)
}

print_line :: proc(buff: ^[dynamic]byte, current_pos: int) {
    // erase current line using ANSI code
    fmt.print("\r\x1b[K")
    print_cursor()
    fmt.print(string(buff[:]))

    col := CURSOR_PREFIX_OFFSET + current_pos
    // move terminal cursor to `col` position 
	fmt.printf("\x1b[%dG", col + 1)
}

read_escape_sequence :: proc(in_stream: io.Reader) -> string {
	seq := make([dynamic]byte)

	append(&seq, '\x1b')

	ch, _, _ := io.read_rune(in_stream)
	append(&seq, byte(ch))

	if ch == '[' {
		// Read final command letter
		cmd, _, _ := io.read_rune(in_stream)
		append(&seq, byte(cmd))
	}

	return string(seq[:])
}

read_console :: proc() -> (string, bool) {
    enable_raw_mode()
    defer disable_raw_mode()

    print_cursor()

    buffer := make([dynamic]byte)
    
	current_pos := 0
    in_stream := os.to_stream(os.stdin)
    previous_symbol := ' '

    for {
        ch, size, err := io.read_rune(in_stream)
        switch {
            case err != nil:
                fmt.eprintfln("\nError: &v", err)
                os.exit(1)
            case ch == '\n':
                fallthrough
            case ch == '\r':
                fmt.println()
			    return string(buffer[:]), true
            case ch == '\u007f':
                fallthrough
            case ch == '\b':
                _, bs_sz := utf8.decode_last_rune(buffer[:])
                if bs_sz > 0 && current_pos > 0 {
                    new := make([dynamic]byte)
                    defer delete(new)

                    append(&new, ..buffer[:current_pos - 1])
                    append(&new, ..buffer[current_pos:])

                    resize(&buffer, len(buffer) - bs_sz)
                    copy(buffer[:], new[:])

                    current_pos -= 1
                    print_line(&buffer, current_pos)
                }
            case ch == '\t':
                compl, is_multi_compl := search_completion(buffer, current_pos)
                is_previous_compl : bool = previous_symbol == '\t'

                if is_multi_compl {
                    if is_previous_compl {
                        fmt.printfln("\n%s", compl)
                        print_line(&buffer, current_pos)
                        previous_symbol = ' '
                    } else {
                        fmt.print("\a")
                    }
                } else {
                    if len(compl) == 0 {
                        fmt.print("\a")
                    } else {
                        append(&buffer, compl)
                        current_pos += len(compl)
        
                        print_line(&buffer, current_pos)
                    }
                }
            case match.is_cntrl(ch):
                seq := read_escape_sequence(in_stream)
                defer delete(seq)

                switch seq {
                    case "\x1b[D":
                        if current_pos == 0 do break
                        fmt.print("\x1b[D")
                        current_pos -= 1
                    case "\x1b[C":
                        if current_pos >= len(buffer) do break
                        fmt.print("\x1b[C")
                        current_pos += 1
                }
            case:
                bytes, _ := utf8.encode_rune(ch)
                inject_at_elems(&buffer, current_pos, ..bytes[:size])
                current_pos += 1

                print_line(&buffer, current_pos)
        }
        previous_symbol = ch
    }
}