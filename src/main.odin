package main

import "core:fmt"
import "core:os"

main :: proc() {
    buf := [1024]u8{}
    fmt.printf("$ ")
    
    total_read, err := os.read(os.stdin, buf[:])
    if err != nil {
        fmt.println(err)
        panic("something went wrong")
    }
    fmt.printf("%s: command not found", string(buf[:total_read-1]))
}
