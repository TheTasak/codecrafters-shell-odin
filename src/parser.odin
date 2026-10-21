package main

import "core:strings"
import "core:fmt"

SpecialSymbols :: []string {
    "'", "\""
}
ESCAPE_SYMBOL := "\\"
ARG_DELIMITER := " "

Arg :: struct {
    value: string,
    start_pos: int,
    end_pos: int,
}

is_in :: proc(str: string, arr: []string) -> bool {
    for element in arr {
        if str == element do return true
    }
    return false
}

search_for_next_symbol :: proc(str: string, symbol: string, start_pos: int) -> int {
    current_pos: int = start_pos
    next_symbol_pos : int
    for {
        next_symbol_pos = strings.index(str[current_pos:], symbol)
        if next_symbol_pos == -1 {
            return -1
        }
        if previous_pos := current_pos+next_symbol_pos-1; previous_pos >= 0 {
            if str[previous_pos:previous_pos+1] != ESCAPE_SYMBOL {
                return current_pos + next_symbol_pos
            } 
        }
        
        current_pos += next_symbol_pos + 1
    }
}

parse_arguments_v2 :: proc(query: string) -> []Arg {
    args_str := query
    args := [dynamic]Arg{}
    
    current_index : int = 0
    if command_index := search_for_next_symbol(args_str, ARG_DELIMITER, 0); command_index != -1 {
        arg := Arg{value=args_str[:command_index], start_pos=0, end_pos=command_index-1}
        current_index = arg.end_pos
        append(&args, arg)
    } else {
        return args[:]
    }

    for {
        fmt.printf("INDEX: %d ARGS: %s\n", current_index, args)
        
        if current_index < len(args_str) {
            current_symbol := args_str[current_index:current_index+1]
            fmt.printf("SYMBOL: %s\n", current_symbol)
            if current_symbol != ARG_DELIMITER {
                current_index += 1
                continue
            }

            if current_index+1 < len(args_str) {
                next_symbol_pos := current_index+1
                next_symbol := args_str[next_symbol_pos:next_symbol_pos+1]

                if is_in(next_symbol, SpecialSymbols) {
                    end_arg_pos := search_for_next_symbol(args_str, next_symbol, next_symbol_pos+1)
                    if end_arg_pos != -1 {
                        arg := Arg{value=args_str[next_symbol_pos:end_arg_pos+1], start_pos=next_symbol_pos, end_pos=end_arg_pos}
                        append(&args, arg)
                        current_index = end_arg_pos
                        continue
                    }
                }
            }

            end_arg_pos := search_for_next_symbol(args_str, ARG_DELIMITER, current_index+1)
            if end_arg_pos == -1 {
                arg := Arg{value=args_str[current_index+1:], start_pos=current_index+1, end_pos=len(args_str)-1}
                append(&args, arg)
                current_index += 1
            } else {
                arg := Arg{value=args_str[current_index+1:end_arg_pos], start_pos=current_index+1, end_pos=end_arg_pos-1}
                append(&args, arg)
                current_index = end_arg_pos
            }
        } else {
            if len(args) > 0 && args[len(args)-1].end_pos+1 < current_index {
                arg := Arg{value=args_str[args[len(args)-1].end_pos+1:], start_pos=args[len(args)-1].end_pos+1, end_pos=len(args_str)-1}
                append(&args, arg)
            }
            break
        }
    }
    fmt.printf("ARGS: %s\n", args)
    return args[:]
}
