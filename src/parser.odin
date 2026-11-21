package main

import "core:strings"
import "core:unicode/utf8"

SINGLE_QUOTE : rune = '\''
DOUBLE_QUOTE : rune = '"'
ESCAPE_SYMBOL : rune = '\\'
ARG_DELIMITER : rune = ' '

STDOUT_REDIRECT_ARR : []string = {">", "1>"}
STDOUT_REDIRECT : rune = '>'
STDERR_REDIRECT : rune = '<'

Arg :: struct {
    value: string,
    type: rune,
    start_pos: int,
    end_pos: int,
}

Flag :: struct {
    name: string,
    usage: string,
    is_required: bool,
    num_args: int,
    arguments: [dynamic]Arg
}

Error :: union #shared_nil {
    FlagParseError
}

FlagParseError :: enum {
    NONE = 0,
    NOT_ENOUGH_ARGS,
    TOO_MANY_ARGS,
    FLAG_NOT_EXISTS
}

str_is_in :: proc(val: string, arr: []string) -> bool {
    for element in arr {
        if val == element do return true
    }
    return false
}

num_is_in :: proc(val: int, arr: []int) -> bool {
    for element in arr {
        if val == element do return true
    }
    return false
}

is_in :: proc{str_is_in, num_is_in}

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
    
    current_index : int = -1

    for {
        space_pos := search_for_next_symbol(args_str, ARG_DELIMITER, current_index+1)
        squote_pos := search_for_next_symbol(args_str, SINGLE_QUOTE, current_index+1)
        dquote_pos := search_for_next_symbol(args_str, DOUBLE_QUOTE, current_index+1)
        first_char := utf8.rune_at(args_str, current_index+1)
        // fmt.printf("FROM: %d:%c, SPACE: %d, S_QUOTE: %d, D_QUOTE: %d\n", current_index+1, first_char, space_pos, squote_pos, dquote_pos)

        if first_char == SINGLE_QUOTE  || first_char == DOUBLE_QUOTE {
            type : rune = first_char
            escape_symbols : bool = type == DOUBLE_QUOTE

            closing := search_for_next_symbol(args_str, type, current_index+1+1, escape_symbols=escape_symbols)
            arg : Arg
            if closing != -1 {
                arg = Arg{value=args_str[current_index+1:closing+1], start_pos=current_index+1, end_pos=closing, type=type}
                append(&args, arg)
            } else {
                arg = Arg{value=args_str[current_index+1:], start_pos=current_index+1, end_pos=len(args_str)-1, type=type}
                append(&args, arg)
                break
            }
            current_index = (closing != -1) ? closing : len(args_str)-1
        } else if (squote_pos < space_pos && squote_pos != -1) || (dquote_pos < space_pos && dquote_pos != -1) {
            type : rune = (squote_pos < space_pos && squote_pos != -1) ? SINGLE_QUOTE : DOUBLE_QUOTE
            pos : int = (type == SINGLE_QUOTE) ? squote_pos : dquote_pos
            escape_symbols : bool = type == DOUBLE_QUOTE

            closing := search_for_next_symbol(args_str, type, pos+1, escape_symbols=escape_symbols)
            arg := Arg{value=args_str[current_index+1:pos], start_pos=current_index+1, end_pos=pos-1, type=ARG_DELIMITER}
            append(&args, arg)
            if closing != -1 {
                arg := Arg{value=args_str[pos:closing+1], start_pos=pos, end_pos=closing, type=type}
                append(&args, arg)
            }
            current_index = (closing != -1) ? closing : pos
        } else if space_pos != -1 {
            arg := Arg{value=args_str[current_index+1:space_pos], start_pos=current_index+1, end_pos=space_pos-1, type=ARG_DELIMITER}
            if arg.start_pos <= arg.end_pos {
                append(&args, arg)
            }
            current_index = space_pos
        } else {
            if len(args) == 0 {
                arg := Arg{value=args_str, start_pos=0, end_pos=len(args_str)-1, type=ARG_DELIMITER}
                append(&args, arg)
            } else if args[len(args)-1].end_pos <= current_index && current_index+1 < len(args_str) {
                first_char := utf8.rune_at(args_str, current_index+1)
                arg_type := (first_char != SINGLE_QUOTE && first_char != DOUBLE_QUOTE) ? ARG_DELIMITER : first_char
                arg := Arg{value=args_str[current_index+1:], start_pos=current_index+1, end_pos=len(args_str)-1, type=arg_type}
                append(&args, arg)
            }
            break
        }
    }
    // fmt.printf("ARGS: %s\n", args)

    for &arg in args {
        strip_escape_symbols(&arg)
    }
    args = merge_args(args)

    // fmt.printf("MERGED ARGS: %s\n", args)

    return args[:]
}

strip_escape_symbols :: proc(arg: ^Arg) {
    new_arg := arg.value
    new_arg, _ = strings.remove_all(new_arg, "\"\"")
    new_arg, _ = strings.remove_all(new_arg, "\'\'")
    if arg.type == DOUBLE_QUOTE || arg.type == ARG_DELIMITER {
        if arg.type == DOUBLE_QUOTE {
            new_arg = new_arg[1:len(new_arg)-1]
        }
        split_arg := strings.split(new_arg, "\\\\")
        for &s in split_arg {
            s, _ = strings.remove_all(s, "\\")
        }
        arg.value = strings.join(split_arg, "\\")
    } else if arg.type == SINGLE_QUOTE {
        arg.value = new_arg[1:len(new_arg)-1]
    }
}

merge_args :: proc(args: [dynamic]Arg) -> [dynamic]Arg {
    new_args := [dynamic]Arg{}

    if len(args) == 0 {
        return args
    }

    current_arg : string = args[0].value
    start_pos : int = 0
    for i := 1; i < len(args); i += 1 {
        if args[i-1].end_pos+1 == args[i].start_pos {
            current_arg = strings.concatenate({current_arg, args[i].value})
        } else {
            arg := Arg{value=current_arg, start_pos=start_pos, end_pos=args[i-1].end_pos, type=args[i-1].type}
            append(&new_args, arg)

            current_arg = args[i].value
            start_pos = args[i].start_pos
        }
    }

    arg := Arg{value=current_arg, start_pos=start_pos, end_pos=args[len(args)-1].end_pos, type=args[len(args)-1].type}
    append(&new_args, arg)
    return new_args
}

parse_redirect :: proc(args: []Arg) -> (position: int, type: rune, file: string, overwrite: bool) {
    for i := 0; i < len(args)-1; i += 1 {
        if args[i].value == "1>" || args[i].value == ">" {
            return i, STDOUT_REDIRECT, args[i+1].value, true
        } else if args[i].value == "1>>" || args[i].value == ">>" {
            return i, STDOUT_REDIRECT, args[i+1].value, false
        } else if args[i].value == "2>" {
            return i, STDERR_REDIRECT, args[i+1].value, true
        } else if args[i].value == "2>>" {
            return i, STDERR_REDIRECT, args[i+1].value, false
        }
    }
    return -1, '_', "", false
}

append_flag_arg :: proc(flags: ^map[string]Flag, name: string, value: Arg) {
    flag := (flags^)[name]
    append_elem(&flag.arguments, value)
    (flags^)[name] = flag
}

parse_flags :: proc(args: []Arg, flags: ^map[string]Flag) -> Error {
    for arg_index := 0; arg_index < len(args); arg_index += 1 {
        arg := args[arg_index]
        if !strings.starts_with(arg.value, "-") {
            // not a flag
            continue
        }
        if arg.value not_in flags {
            return FlagParseError.FLAG_NOT_EXISTS
        }
        current_flag := flags[arg.value]
        for i := 0; i < current_flag.num_args && len(current_flag.arguments) < current_flag.num_args; i += 1 {
            if arg_index + 1 < len(args) {
                arg_index += 1
                append_flag_arg(flags, arg.value, args[arg_index])
            } else {
                return FlagParseError.NOT_ENOUGH_ARGS
            }
        }
    }

    for key, value in flags {
        if value.is_required {
            if len(value.arguments) < value.num_args do return FlagParseError.NOT_ENOUGH_ARGS
            else if len(value.arguments) > value.num_args do return FlagParseError.TOO_MANY_ARGS
        } else {
            if len(value.arguments) > 0 && value.num_args > 0 {
                if len(value.arguments) < value.num_args do return FlagParseError.NOT_ENOUGH_ARGS
                else if len(value.arguments) > value.num_args do return FlagParseError.TOO_MANY_ARGS
            } else {
                delete_key(flags, key)
            }
        }
    }
    return FlagParseError.NONE
}