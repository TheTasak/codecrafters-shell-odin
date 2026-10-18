package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"

Command :: enum {
    EXIT,
    ECHO,
    TYPE,
    PWD,
}

Commands :: [Command]string {
    .EXIT = "exit",
    .ECHO = "echo",
    .TYPE = "type",
    .PWD = "pwd"
}


is_executable :: proc(filepath: string) -> bool {
    if os.exists(filepath){
        perms, err := os.stat(filepath, context.allocator)
        defer os.file_info_delete(perms, context.allocator)
        if .Execute_User in perms.mode && err == nil {
            return true
        }
    }
    return false
}

get_env_path :: proc(command: string) -> string {
    buf := [2048]u8{}
    path_var := os.get_env_buf(buf[:], "PATH")
    paths := strings.split(string(path_var), ":")
    
    for path in paths {
        filepath := strings.concatenate({path, "/", command})
        if is_executable(filepath) {
            return filepath
        }
    }
    return ""
}

check_external :: proc(command: string, args: string) -> (string, bool) {
    if path := get_env_path(command); path != "" {
        return path, true
    }
    return "", false
}

echo :: proc(args: string) {
    fmt.printf("%s\n", args)
}

type :: proc(args: string) {
    // locate built-in commands 
    for c in Commands {
        if strings.starts_with(args, c) {
            fmt.printf("%s is a shell builtin\n", c)
            return
        }
    }

    // locate executables using PATH
    path := get_env_path(args)
    if path != "" {
        fmt.printf("%s is %s\n", args, path)
    } else {
        fmt.printf("%s: not found\n", args)
    }
}

pwd :: proc() {
    path, err := os.get_executable_directory(context.temp_allocator)
    if err != nil {
        fmt.printf("%s\n", err)
    } else {
        fmt.printf("%s\n", path)
    }
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

        query := strings.trim_right(string(buf[:total_read]), "\n")
        command, args : string
        if i := strings.index(query, " "); i != -1 {
            command = query[:i]
            args = query[i+1:]
        } else {
            command = query
            args = ""
        }

        // fmt.printf("%s: %s\n", command, args)

        if command == Commands[Command.EXIT] {
            break
        } else if command == Commands[Command.ECHO] {
            echo(args)
        } else if command == Commands[Command.TYPE] {
            type(args)
        } else if command == Commands[Command.PWD] {
            pwd()
        } else {
            if path, exists := check_external(command, args); exists {
                desc := os.Process_Desc{
                    command = strings.split(query, " ")
                }
                state, stdout, stderr, _ := os.process_exec(desc, context.allocator)
                defer delete(stdout)
                defer delete(stderr)

                if !state.success {
                    fmt.printf("%s", string(stderr))
                } else {
                    fmt.printf("%s", string(stdout))
                }
            } else {
                fmt.printf("%s: command not found\n", command)
            }
        }
    }
}
