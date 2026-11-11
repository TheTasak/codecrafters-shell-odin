package main

import "core:sort"
import "core:text/match"
import "core:unicode/utf8"
import "core:io"
import "core:os"
import "core:sys/posix"
import "core:fmt"
import "core:strings"

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

search_completion :: proc(buff: [dynamic]byte) -> (compl: string, next_line: bool) {
    possible_compl := make([dynamic]string)
    defer delete(possible_compl)

    args := parse_arguments(string(buff[:]))
    for cmd in Commands {
        if strings.starts_with(cmd, args[0].value) {
            append(&possible_compl, cmd)
        } 
    }
    
    external_paths := list_env_paths()
    for path in external_paths {
        files, err := os.read_all_directory_by_path(path, context.allocator)
        if err != nil {
            continue
        }

        for file in files {
            if strings.starts_with(file.name, args[0].value) && is_executable(file.fullpath) {
                append(&possible_compl, file.name)
            }
        }
    }

    seen := make(map[string]bool)
    defer delete(seen)
    uniq_compl := make([dynamic]string, context.temp_allocator)
    defer delete(uniq_compl)

    for compl in possible_compl {
        if !seen[compl] {
            seen[compl] = true
            append(&uniq_compl, compl)
        }
    }

    sort.quick_sort(uniq_compl[:])

    if len(uniq_compl) > 1 {
        return strings.join(uniq_compl[:], "  "), true
    } else if len(uniq_compl) == 1 {
        return strings.concatenate({uniq_compl[0][len(args[0].value):], " "}), false
    }

    return "", false
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
                compl, is_multi_compl := search_completion(buffer)
                is_previous_compl : bool = previous_symbol == '\t'

                if is_multi_compl {
                    if is_previous_compl {
                        fmt.printfln("\n%s", compl)
                        print_line(&buffer, current_pos)
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