package tests

import "core:testing"
import app "../src"

@(test)
test_search_for_next_symbol :: proc(t: ^testing.T) {
    testing.expect_value(t, app.search_for_next_symbol("a b c", " ", 2), 3)
    testing.expect_value(t, app.search_for_next_symbol("a b c", " ", 4), -1)
    testing.expect_value(t, app.search_for_next_symbol("a\\ b c", " ", 3), 4)
    testing.expect_value(t, app.search_for_next_symbol("a\\ b\\ c", " ", 3), -1)
    testing.expect_value(t, app.search_for_next_symbol("a 'b' c", "'", 3), 4)
    testing.expect_value(t, app.search_for_next_symbol("abec", " ", 0), -1)
    testing.expect_value(t, app.search_for_next_symbol("", " ", 0), -1)
}