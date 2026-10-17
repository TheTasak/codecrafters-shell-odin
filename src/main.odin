package main

import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
    buf := [1024]u8{}
    fmt.printf("$ ")
    
    total_read, err := os.read(os.stdin, buf[:])
    if err != nil {
        fmt.println(err)
        panic("something went wrong")
    }
    command := strings.trim_right(string(buf[:total_read]), "\n")
    fmt.printf("%s: command not found", command)
}
