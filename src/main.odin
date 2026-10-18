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
    CD,
}

Commands :: [Command]string {
    .EXIT = "exit",
    .ECHO = "echo",
    .TYPE = "type",
    .PWD = "pwd",
    .CD = "cd"
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

parse_arguments :: proc(command: string, args_str: string) -> []string {
    args := [dynamic]string{}
    append(&args, command)
    args_str, _ := strings.replace_all(args_str, "''", "")

    if args_str != "" {
        start_index : int = 0
        for {
            outside_boundary : bool = start_index < len(args_str) - 1
            if i := strings.index(args_str[start_index:], "'"); i != -1 && outside_boundary {
                end_index := start_index + i
                if is_allowed_argument(args_str, start_index, end_index) {
                    append(&args, args_str[start_index:end_index])
                }
                start_index = start_index + i + 1
            } else if i := strings.index(args_str[start_index:], " "); i != -1 && outside_boundary {
                end_index := start_index + i
                if is_allowed_argument(args_str, start_index, end_index) {
                    append(&args, args_str[start_index:end_index])
                }
                start_index = start_index + i + 1
            } else {
                if start_index < len(args_str) {
                    append(&args, args_str[start_index:])
                }
                break
            }
        }
        // fmt.printf("ARGS: %s\n", args)
    }
    return args[:]
}

check_external :: proc(command: string) -> (string, bool) {
    if path := get_env_path(command); path != "" {
        return path, true
    }
    return "", false
}

execute_program :: proc(args: []string) {
    desc := os.Process_Desc{
        command = args
    }
    state, stdout, stderr, _ := os.process_exec(desc, context.allocator)
    defer delete(stdout)
    defer delete(stderr)

    if !state.success {
        fmt.printf("%s", string(stderr))
    } else {
        fmt.printf("%s", string(stdout))
    }
}

is_allowed_argument :: proc(arg: string, start_pos: int, end_pos: int) -> bool {
    current_arg := arg[start_pos:end_pos]
    return (start_pos != end_pos) && (len(strings.trim(current_arg, " ")) > 0)
}

echo :: proc(args: ..string) {
    for arg in args {
        fmt.printf("%s ", arg)
    }
    fmt.printf("\n")
}

type :: proc(args: []string) {
    if len(args) < 2 {
        fmt.printf("type: no command specified\n")
        return
    }
    command := args[1]
    // locate built-in commands 
    for c in Commands {
        if strings.starts_with(command, c) {
            fmt.printf("%s is a shell builtin\n", c)
            return
        }
    }

    // locate executables using PATH
    path := get_env_path(command)
    if path != "" {
        fmt.printf("%s is %s\n", command, path)
    } else {
        fmt.printf("%s: not found\n", command)
    }
}

pwd :: proc() {
    path, err := os.get_working_directory(context.temp_allocator)
    if err != nil {
        fmt.printf("%s\n", err)
    } else {
        fmt.printf("%s\n", path)
    }
}

cd :: proc(args: []string) {
    if len(args) < 2 {
        fmt.printf("cd: no directory specified\n")
        return
    }
    path := args[1]
    if strings.starts_with(path, "~") {
        buf := [256]u8{}
        path_var := os.get_env_buf(buf[:], "HOME")
        path, _ = strings.replace(path, "~", path_var, 1)
    }
    if err := os.change_directory(path); err != nil {
        fmt.printf("cd: %s: No such file or directory\n", path)
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
        command, args_str : string
        if i := strings.index(query, " "); i != -1 {
            command = query[:i]
            args_str = query[i+1:]
        } else {
            command = query
            args_str = ""
        }
        args := parse_arguments(command, args_str)
        
        if command == Commands[Command.EXIT] {
            break
        } else if command == Commands[Command.ECHO] {
            echo(strings.join(args[1:], " "))
        } else if command == Commands[Command.TYPE] {
            type(args)
        } else if command == Commands[Command.PWD] {
            pwd()
        } else if command == Commands[Command.CD] {
            cd(args)
        } else {
            if path, exists := check_external(command); exists {
                execute_program(args)
            } else {
                fmt.printf("%s: command not found\n", command)
            }
        }
    }
}
