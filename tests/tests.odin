package tests

import "core:testing"
import "core:fmt"
import app "../src"

@(test)
test_search_for_next_symbol :: proc(t: ^testing.T) {
    args := []app.Arg{app.Arg{value="cat: \"/tmp/'no slash 1\": No such file or directory", type=' '}, app.Arg{value="cat: \"/tmp/'one slash \\2': No such file or directory", type=' '}}
    args_result := app.parse_arguments("cat /tmp/'no slash 1' /tmp/'one slash \\2'")
    fmt.printf("RESULT: %s\n", args_result)
}