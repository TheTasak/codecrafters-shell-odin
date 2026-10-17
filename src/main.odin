package main

import "core:fmt"
import "core:os"
import "core:strings"

BREAK_COMMAND :: "exit"
ECHO_COMMAND :: "echo"

echo :: proc(args: string) {
    fmt.printf("%s\n", args)
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
            echo(command[len(ECHO_COMMAND)+1:])
        } else {
            fmt.printf("%s: command not found\n", command)
        }
    }
}
