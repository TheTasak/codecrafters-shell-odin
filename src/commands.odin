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
    WRITE,
    COMPLETE,
}

Commands :: [Command]string {
    .EXIT = "exit",
    .ECHO = "echo",
    .TYPE = "type",
    .PWD = "pwd",
    .CD = "cd",
    .WRITE = "write",
    .COMPLETE = "complete"
}

Output :: struct {
    stdout: string,
    stderr: string,
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

list_env_paths :: proc() -> []string {
    path_var := os.get_env_alloc("PATH", context.temp_allocator)
    paths := strings.split(string(path_var), ":")
    return paths
}

get_env_path :: proc(command: string) -> string {
    paths := list_env_paths()
    
    for path in paths {
        filepath := strings.concatenate({path, "/", command})
        if is_executable(filepath) {
            return filepath
        }
    }
    return ""
}

check_external :: proc(command: string) -> (string, bool) {
    if path := get_env_path(command); path != "" {
        return path, true
    }
    return "", false
}

execute_program :: proc(args: []Arg) -> Output {
    args_value := [dynamic]string{}
    for arg in args {
        append(&args_value, arg.value)
    }

    desc := os.Process_Desc{
        command = args_value[:]
    }
    state, stdout, stderr, err := os.process_exec(desc, context.allocator)
    if err != nil {
        return Output{stderr=os.error_string(err)}
    }

    return Output{stdout=string(stdout), stderr=string(stderr)}
}

echo :: proc(args: []Arg) -> Output {
    output_arr : [dynamic]string

    for arg in args {
        append(&output_arr, arg.value)
    }

    return Output{stdout=strings.concatenate({strings.join(output_arr[:], " "), "\n"})}
}

type :: proc(args: []Arg) -> Output {
    if len(args) == 0 {
        return Output{stderr="type: no command specified\n"}
    }
    command := args[0].value

    // locate built-in commands 
    for c in Commands {
        if strings.starts_with(command, c) {
            return Output{stdout=fmt.aprintf("%s is a shell builtin\n", c)}
        }
    }

    // locate executables using PATH
    path := get_env_path(command)
    if path != "" {
        return Output{stdout=fmt.aprintf("%s is %s\n", command, path)}
    } else {
        return Output{stderr=fmt.aprintf("%s: not found\n", command)}
    }
}

pwd :: proc() -> Output {
    path, err := os.get_working_directory(context.temp_allocator)
    if err != nil {
        return Output{stderr=fmt.aprintf("%s\n", err)}
    } else {
        return Output{stdout=fmt.aprintf("%s\n", path)}
    }
}

cd :: proc(args: []Arg) -> Output {
    if len(args) == 0 {
        return Output{stderr="cd: no directory specified\n"}
    }

    path := args[0].value
    if strings.starts_with(path, "~") {
        buf := [256]u8{}
        path_var := os.get_env_buf(buf[:], "HOME")
        path, _ = strings.replace(path, "~", path_var, 1)
    }
    if err := os.change_directory(path); err != nil {
        return Output{stderr=fmt.aprintf("cd: %s: No such file or directory\n", path)}
    }
    return Output{}
}

save_to_file :: proc(filename: string, content: string, overwrite: bool = true) -> Output {
    file : ^os.File
    error : os.Error
    flags : os.File_Flags

    if overwrite {
        flags = os.File_Flags{.Write, .Trunc}
    } else {
        flags = os.File_Flags{.Write, .Append}
    }

    if os.exists(filename) {
        file, error = os.open(filename, flags=flags)
    } else {
        file, error = os.create(filename)
    }
    defer os.close(file)

    if error != nil {
        return Output{stderr=os.error_string(error)}
    }

    _, error = os.write_string(file, content)
    if error != nil {
        return Output{stderr=os.error_string(error)}
    }
    return Output{}
}

complete :: proc(args: []Arg, registered_completions: ^map[string]string) -> Output {
    flags := make_map(map[string]Flag)
    flags["-C"] = Flag{name = "-C", num_args = 2, arguments = {}}
    flags["-p"] = Flag{name = "-p", num_args = 1, arguments = {}}

    err := parse_flags(args, &flags)
    if err != nil {
        // would be cool to print the text that is related to the error from parsing
        return Output{stderr="complete: error\n"}
    }

    for key, flag in flags {
        if key == "-p" {
            compl_type := flag.arguments[0].value
            if compl_type in registered_completions {
                compl := registered_completions[compl_type]
                return Output{stdout=fmt.aprintf("complete -C '%s' %s\n", compl, compl_type)}
            } else {
                return Output{stderr=fmt.aprintf("complete: %s: no completion specification\n", compl_type)}
            }
        } else if key == "-C" {
            registered_completions[flag.arguments[1].value] = flag.arguments[0].value
            return Output{}
        }
    }
    return Output{stdout=""}
}