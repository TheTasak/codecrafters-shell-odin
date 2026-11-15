package main

import "core:strings"
import "core:sort"
import "core:os"
import "core:fmt"

longest_common_prefix :: proc(options: []string) -> string {
    if len(options) <= 1 {
        return ""
    }

    min_length : int
    for opt in options {
        if len(opt) < min_length do min_length = len(opt)
    }

    for letter, letter_index in options[0] {
        for i := 1; i < len(options); i += 1 {
            if letter != rune(options[i][letter_index]) {
                return options[0][:letter_index]
            }
        }
    }
    return options[0]
}

get_command_completions :: proc(args: []Arg) -> [dynamic]string {
    possible_compl := make([dynamic]string)
    
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
    return possible_compl
}

get_file_completions :: proc(args: []Arg) -> [dynamic]string {
    possible_compl := make([dynamic]string)

    last_arg := args[len(args)-1]
    directory, wd_err := os.get_working_directory(context.temp_allocator)
    if wd_err != nil {
        fmt.eprintfln("%s", wd_err)
        return possible_compl
    }

    dir_obj, open_err := os.open(directory)
    if open_err != nil {
        fmt.eprintfln("%s", open_err)
        return possible_compl
    }

    file_info, err := os.read_all_directory(dir_obj, context.allocator)
    if err != nil {
        fmt.eprintfln("%s", err)
        return possible_compl
    }

    for file in file_info {
        if strings.starts_with(file.name, last_arg.value) {
            fmt.printf("%s ", file.name)
            append(&possible_compl, file.name)
        }
    }
    return possible_compl
}

search_completion :: proc(buff: [dynamic]byte, cursor_pos: int) -> (compl: string, next_line: bool) {
    args := parse_arguments(string(buff[:]))
    // TODO: add choosing the argument based on cursor position, so that mid string completions are possible
    current_arg := args[len(args)-1] 

    possible_compl : [dynamic]string
    if len(args) > 1 {
        possible_compl = get_file_completions(args)
    } else {
        possible_compl = get_command_completions(args)
    }
    defer delete(possible_compl)

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
    prefix := longest_common_prefix(uniq_compl[:])

    if len(prefix) > len(current_arg.value) {
        return prefix[len(current_arg.value):], false
    }

    if len(uniq_compl) > 1 {
        return strings.join(uniq_compl[:], "  "), true
    } else if len(uniq_compl) == 1 {
        return strings.concatenate({uniq_compl[0][len(current_arg.value):], " "}), false
    }

    return "", false
}
