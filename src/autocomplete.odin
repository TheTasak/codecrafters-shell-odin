package main

import "core:strings"
import "core:sort"
import "core:os"
import "core:fmt"

longest_common_prefix :: proc(options: []string) -> string {
    if len(options) <= 1 {
        return ""
    }

    min_length : int = len(options[0])
    for opt in options {
        if len(opt) < min_length do min_length = len(opt)
    }

    for letter_i := 0; letter_i < min_length; letter_i += 1 {
        for option_i := 1; option_i < len(options); option_i += 1 {
            if options[0][letter_i] != options[option_i][letter_i] {
                return options[0][:letter_i]
            }
        }
    }
    return options[0][:min_length]
}

get_unique :: proc(compl: ^[dynamic]string) -> [dynamic]string {
    seen := make(map[string]bool, context.temp_allocator)
    defer delete(seen)
    uniq_compl := make([dynamic]string)

    for record in compl {
        if !seen[record] {
            seen[record] = true
            append(&uniq_compl, record)
        }
    }
    return uniq_compl
}

get_command_completions :: proc(prefix: string) -> [dynamic]string {
    possible_compl := make([dynamic]string)
    
    for cmd in Commands {
        if strings.starts_with(cmd, prefix) {
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
            if strings.starts_with(file.name, prefix) && is_executable(file.fullpath) {
                append(&possible_compl, file.name)
            }
        }
    }
    return possible_compl
}

get_file_completions :: proc(prefix: string) -> [dynamic]string {
    prefix_string := prefix
    possible_compl := make([dynamic]string)

    directory, wd_err := os.get_working_directory(context.temp_allocator)
    if wd_err != nil {
        fmt.eprintfln("%s", wd_err)
        return possible_compl
    }

    dir_index := strings.last_index(prefix_string, "/")
    if dir_index != -1 {
        directory = strings.concatenate({directory, "/", prefix_string[:dir_index]})
        prefix_string = prefix_string[dir_index+1:]
    }

    file_info, err := os.read_all_directory_by_path(directory, context.allocator)
    if err != nil {
        fmt.eprintfln("%s", err)
        return possible_compl
    }

    for file in file_info {
        if strings.starts_with(file.name, prefix_string) {
            completion : string
            file_path := file.name
            if file.type == os.File_Type.Directory {
                file_path = strings.concatenate({file_path, "/"})
            }

            if dir_index != -1 {
                completion = strings.concatenate({prefix[:dir_index], "/", file_path})
            } else {
                completion = file_path
            }
            append(&possible_compl, completion)
        }
    }
    return possible_compl
}

get_custom_completions :: proc(program_filepath: string) -> [dynamic]string {
    possible_compl := make([dynamic]string, context.allocator)

    process_desc := os.Process_Desc{command={program_filepath}}
    state, stdout, stderr, err := os.process_exec(process_desc, context.allocator)
    // stdout should be freed, think how, it now fucks up the compl list if deleted
    // defer delete(stdout)
    defer delete(stderr)

    if !state.success || err != nil {
        fmt.eprintfln("%s", err)
        return possible_compl
    }

    compl := strings.split(string(stdout[:]), "\n")
    
    for row in compl {
        if len(row) > 0 do append(&possible_compl, row)
    }

    return possible_compl
}

search_completion :: proc(buff: [dynamic]byte, registered_completions: ^map[string]string, cursor_pos: int) -> (compl: string, next_line: bool) {
    args := parse_arguments(string(buff[:]))
    // TODO: add choosing the argument based on cursor position, so that mid string completions are possible
    current_arg := args[len(args)-1].value
    is_empty_arg : bool = (args[len(args)-1].end_pos + 1 < cursor_pos)

    possible_compl : [dynamic]string
    defer delete(possible_compl)
    
    if is_empty_arg && current_arg in registered_completions {
        possible_compl = get_custom_completions(registered_completions[current_arg])
    } else if is_empty_arg {
        possible_compl = get_file_completions("")
    } else if len(args) > 1 {
        possible_compl = get_file_completions(current_arg)
    } else {
        possible_compl = get_command_completions(current_arg)
    }

    uniq_compl := get_unique(&possible_compl)
    defer delete(uniq_compl)

    prefix := longest_common_prefix(uniq_compl[:])
    if len(prefix) > len(current_arg) {
        return prefix[len(current_arg):], false
    }

    if len(uniq_compl) > 1 {
        sort.quick_sort(uniq_compl[:])
        return strings.join(uniq_compl[:], "  "), true
    } else if len(uniq_compl) == 1 {
        compl_value : string = is_empty_arg ? uniq_compl[0] : uniq_compl[0][len(current_arg):]
        compl_last_char := rune(compl_value[len(compl_value)-1])

        if compl_last_char == '/' {
            return compl_value, false
        } else {
            return strings.concatenate({compl_value, " "}), false
        }
    }

    return "", false
}
