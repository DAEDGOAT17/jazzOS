bits 16
org 0x20000

start:
    cli
    ; Print '1' to screen
    mov ax, 0xb800
    mov es, ax
    mov word [es:0], 0x0f31

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Enable A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Print '2'
    mov word [es:2], 0x0f32

    ; --- THE FIX: FORCE PHYSICAL ADDRESS ---
    ; We manually point the LGDT to 0x20000 + the offset of the descriptor
    lgdt [gdt_descriptor]
    
    ; Switch to Protected Mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; --- THE FIX: FORCE ABSOLUTE FAR JUMP ---
    ; We must jump to 0x08:0x20xxx. 
    ; If NASM is giving us '37 00', we must add the 0x20000 base.
    jmp 0x08:0x20000 + (init_pm - start)

[bits 32]
init_pm:
    ; Print '3'
    mov eax, 0x0f33
    mov [0xb8004], ax

    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; Print '4'
    mov eax, 0x0f34
    mov [0xb8006], ax

    jmp 0x21000

align 8
gdt_start:
    dq 0x0000000000000000 
    dq 0x00CF9A000000FFFF 
    dq 0x00CF92000000FFFF 
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0x20000 + (gdt_start - start) ; FORCE physical 0x20xxx address

times 4096-($-$$) db 0