package main

import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
    buf := [1024]u8{}
    for {
        fmt.printf("$ ")
        
        total_read, err := os.read(os.stdin, buf[:])
        if err != nil {
            fmt.println(err)
            panic("something went wrong")
        }

        query := strings.trim_right(string(buf[:total_read]), "\n")
        query = strings.trim(query, " ")
        args := parse_arguments(query)
        command := args[0].value

        redirect_pos, redirect_type, redirect_file, overwrite := parse_redirect(args)
        if redirect_pos != -1 {
            args = args[:redirect_pos]
        }

        output: Output
        
        if command == Commands[Command.EXIT] {
            break
        } else if command == Commands[Command.ECHO] {
            output = echo(args[1:])
        } else if command == Commands[Command.TYPE] {
            output = type(args[1:])
        } else if command == Commands[Command.PWD] {
            output = pwd()
        } else if command == Commands[Command.CD] {
            output = cd(args[1:])
        } else {
            if path, exists := check_external(command); exists {
                output = execute_program(args)
            } else {
                output = Output{stderr=fmt.aprintf("%s: command not found\n", command)}
            }
        }

        if redirect_pos != -1 && redirect_type == STDOUT_REDIRECT {
            save_to_file(redirect_file, output.stdout, overwrite)
        } else if len(output.stdout) > 0 {
            fmt.printf("%s", output.stdout)
        }

        if redirect_pos != -1 && redirect_type == STDERR_REDIRECT {
            save_to_file(redirect_file, output.stderr, overwrite)
        } else if len(output.stderr) > 0 {
            fmt.printf("%s", output.stderr)
        }
    }
}
