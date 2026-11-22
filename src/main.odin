package main

import "core:fmt"
import "core:strings"

main :: proc() {
    registered_completions := make(map[string]string)
    defer delete(registered_completions)

    for {
        buf, _ := read_console(&registered_completions)
        query := strings.trim(buf, " ")
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
        } else if command == Commands[Command.COMPLETE] {
            output = complete(args[1:], &registered_completions)
        } else if command == Commands[Command.JOBS] {
            output = jobs()
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
