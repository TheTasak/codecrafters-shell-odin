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

    if start_pos >= len(str) {
        return -1
    }

    for {
        next_symbol_pos := strings.index(str[current_pos:], symbol)
        if next_symbol_pos == -1 {
            return -1
        }
        next_symbol_pos = current_pos + next_symbol_pos

        if previous_pos := next_symbol_pos-1; previous_pos >= 0 {
            if str[previous_pos:previous_pos+1] != ESCAPE_SYMBOL {
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
        arg := Arg{value=args_str[:command_index], start_pos=0, end_pos=command_index-1}
        current_index = command_index
        append(&args, arg)
    } else {
        return args[:]
    }

    for {
        if current_index+1 < len(args_str) {
            next_symbol_pos := current_index+1
            next_symbol := args_str[next_symbol_pos:next_symbol_pos+1]

            if is_in(next_symbol, SpecialSymbols) {
                end_arg_pos := search_for_next_symbol(args_str, next_symbol, next_symbol_pos+1)
                if end_arg_pos != -1 {
                    arg := Arg{value=args_str[next_symbol_pos:end_arg_pos+1], start_pos=next_symbol_pos, end_pos=end_arg_pos}
                    append(&args, arg)
                    current_index = end_arg_pos+1
                    continue
                }
            }
        }

        // TODO: check if firstly we should treat the argument as inside quotes
        pos := search_for_next_symbol(args_str, ARG_DELIMITER, current_index+1)

        if pos == -1 {
            if args[len(args)-1].end_pos < current_index && current_index+1 < len(args_str) {
                arg := Arg{value=args_str[current_index+1:], start_pos=current_index+1, end_pos=len(args_str)-1}
                append(&args, arg)
            }
            break
        }

        arg := Arg{value=args_str[current_index+1:pos], start_pos=current_index+1, end_pos=pos-1}
        append(&args, arg)
        current_index = pos
    }

    for &arg in args {
        arg.value = strip_quotes(arg.value)
    }
    return args[:]
}

strip_quotes :: proc(arg: string) -> string {
    new_arg := arg
    if is_in(new_arg[0:1], SpecialSymbols) && new_arg[0:1] == new_arg[len(new_arg)-1:] {
        new_arg = new_arg[1:len(new_arg)-1]
    }
    return new_arg
}