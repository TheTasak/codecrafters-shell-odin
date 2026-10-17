package main

import "core:fmt"
import "core:os"
import "core:strings"

BREAK_COMMAND :: "exit"
ECHO_COMMAND :: "echo"
TYPE_COMMAND :: "type"
BUILTIN_COMMANDS :: []string{BREAK_COMMAND, ECHO_COMMAND, TYPE_COMMAND}

echo :: proc(args: string) {
    fmt.printf("%s\n", args)
}

type :: proc(args: string) {
    for c in BUILTIN_COMMANDS {
        if strings.starts_with(args, c) {
            fmt.printf("%s is a shell builtin\n", c)
            return
        }
    }
    fmt.printf("%s: not found\n", args)
}

get_args :: proc(s: string, command: string) -> string {
    return s[len(command)+1:]
}

main :: proc() {
    buf := [1024]u8{}
    for {
        fmt.printf("$ ")
        
        total_read, err := os.read(os.stdin, buf[:])
        if err != nil {
            fmt.println(err)
            panic("something went wrong")
        }
        command := strings.trim_right(string(buf[:total_read]), "\n")

        if command == BREAK_COMMAND {
            break
        } else if strings.starts_with(command, ECHO_COMMAND + " ") {
            echo(get_args(command, ECHO_COMMAND))
        } else if strings.starts_with(command, TYPE_COMMAND + " ") {
            type(get_args(command, TYPE_COMMAND))
        } else {
            fmt.printf("%s: command not found\n", command)
        }
    }
}
