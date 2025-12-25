[bits 32]
global _start
extern kernel_main

_start:
    jmp $    ; <--- ADD THIS LINE TEMPORARILY
    call kernel_main