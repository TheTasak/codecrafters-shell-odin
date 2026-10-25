package main

import "core:strings"
import "core:fmt"
import "core:unicode/utf8"

SINGLE_QUOTE : rune = '\''
DOUBLE_QUOTE : rune = '"'
ESCAPE_SYMBOL : rune = '\\'
ARG_DELIMITER : rune = ' '

Arg :: struct {
    value: string,
    type: rune,
    start_pos: int,
    end_pos: int,
}

is_in :: proc(str: string, arr: []string) -> bool {
    for element in arr {
        if str == element do return true
    }
    return false
}

search_for_next_symbol :: proc(str: string, symbol: rune, start_pos: int, escape_symbols: bool = true) -> int {
    current_pos: int = start_pos

    if start_pos >= len(str) {
        return -1
    }

    for {
        next_symbol_pos := strings.index_rune(str[current_pos:], symbol)
        if next_symbol_pos == -1 {
            return -1
        }
        next_symbol_pos = current_pos + next_symbol_pos

        if previous_pos := next_symbol_pos-1; previous_pos >= 0 {
            if !escape_symbols || utf8.rune_at(str, previous_pos) != ESCAPE_SYMBOL {
                return next_symbol_pos
            }
        }
        
        current_pos = next_symbol_pos + 1
    }
}

parse_arguments :: proc(query: string) -> []Arg {
    args_str := query
    args := [dynamic]Arg{}
    
    current_index : int = 0
    if command_index := search_for_next_symbol(args_str, ARG_DELIMITER, 0); command_index != -1 {
        arg := Arg{value=args_str[:command_index], start_pos=0, end_pos=command_index-1, type=ARG_DELIMITER}
        current_index = command_index
        append(&args, arg)
    } else {
        arg := Arg{value=args_str, start_pos=0, end_pos=len(args_str)-1, type=ARG_DELIMITER}
        append(&args, arg)
        return args[:]
    }

    for {
        if current_index+1 < len(args_str) {
            next_symbol_pos := current_index+1
            next_symbol := utf8.rune_at(args_str, next_symbol_pos)

            if next_symbol == SINGLE_QUOTE || next_symbol == DOUBLE_QUOTE {
                end_arg_pos := search_for_next_symbol(args_str, next_symbol, next_symbol_pos+1)
                if end_arg_pos != -1 {
                    arg := Arg{value=args_str[next_symbol_pos:end_arg_pos+1], start_pos=next_symbol_pos, end_pos=end_arg_pos, type=next_symbol}
                    append(&args, arg)
                    current_index = end_arg_pos
                    continue
                }
            }
        }

        pos := search_for_next_symbol(args_str, ARG_DELIMITER, current_index+1)

        if pos == -1 {
            if args[len(args)-1].end_pos < current_index && current_index+1 < len(args_str) {
                arg := Arg{value=args_str[current_index+1:], start_pos=current_index+1, end_pos=len(args_str)-1, type=ARG_DELIMITER}
                append(&args, arg)
            }
            break
        }

        arg := Arg{value=args_str[current_index+1:pos], start_pos=current_index+1, end_pos=pos-1, type=ARG_DELIMITER}
        if arg.start_pos <= arg.end_pos {
            append(&args, arg)
        }
        current_index = pos
    }
    // fmt.printf("ARGS: %s\n", args)

    for &arg in args {
        arg.value = strip_quotes(arg.value)
        arg.value = strip_escape_symbols(arg.value)
    }

    args = merge_args(args)

    // fmt.printf("MERGED ARGS: %s\n", args)

    return args[:]
}

strip_quotes :: proc(arg: string) -> string {
    new_arg := arg
    first_rune := utf8.rune_at(new_arg, 0)
    last_rune := utf8.rune_at(new_arg, len(arg)-1)
    if len(new_arg) > 2 && (first_rune == SINGLE_QUOTE || first_rune == DOUBLE_QUOTE) && first_rune == last_rune {
        new_arg = new_arg[1:len(new_arg)-1]
    }
    return new_arg
}

strip_escape_symbols :: proc(arg: string) -> string {
    new_arg, _ := strings.remove_all(arg, "\"\"")
    new_arg, _ = strings.remove_all(new_arg, "\'\'")
    split_arg := strings.split(new_arg, "\\\\")
    for &s in split_arg {
        s, _ = strings.remove_all(s, "\\")
    }
    return strings.join(split_arg, "\\")
}

merge_args :: proc(args: [dynamic]Arg) -> [dynamic]Arg {
    new_args := [dynamic]Arg{}
    for i := 0; i < len(args); i += 1 {
        if i+1 < len(args) && args[i].end_pos+1 == args[i+1].start_pos && args[i].type == args[i+1].type {
            arg := Arg{value=strings.concatenate({args[i].value, args[i+1].value}), start_pos=args[i].start_pos, end_pos=args[i+1].end_pos}
            append(&new_args, arg)
            i += 1
        } else {
            append(&new_args, args[i])
        }
    }
    return new_args
}