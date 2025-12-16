org 0x0000
bits 16

%define ENDL 0x0D, 0x0A
%define BACKSPACE 0x08
%define ENTER     0x0D

BUFFER_SIZE equ 64

; --------------------
; ENTRY POINT
; --------------------
start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov byte [buf_len], 0

    mov si, msg_welcome
    call puts
    call print_prompt

main_loop:
    mov ah, 0
    int 16h            ; read key

    cmp al, ENTER
    je handle_enter

    cmp al, BACKSPACE
    je handle_backspace

    ; ignore non-printable
    cmp al, 0x20
    jb main_loop

    mov bl, [buf_len]
    cmp bl, BUFFER_SIZE-1
    jae main_loop

    mov di, input_buffer
    add di, bx
    mov [di], al
    inc byte [buf_len]

    ; echo char
    mov ah, 0x0E
    mov bh, 0
    int 10h

    jmp main_loop

; --------------------
; ENTER KEY
; --------------------
handle_enter:
    call newline

    mov bl, [buf_len]
    mov di, input_buffer
    add di, bx
    mov byte [di], 0

    ; check HELP
    mov si, input_buffer
    mov di, cmd_help
    call strcmp
    cmp ax, 1
    je cmd_help_exec

    ; check CLEAR
    mov si, input_buffer
    mov di, cmd_clear
    call strcmp
    cmp ax, 1
    je cmd_clear_exec

    ; check VERSION
    mov si, input_buffer
    mov di, cmd_version
    call strcmp
    cmp ax, 1
    je cmd_version_exec

    ; check ECHO (special handling)
    mov si, input_buffer
    mov di, cmd_echo
    call strncmp_echo
    cmp ax, 1
    je cmd_echo_exec

    mov si, msg_unknown
    call puts
    call newline
    jmp after_command

; --------------------
; VERSION COMMAND
; --------------------
cmd_version_exec:
    mov si, msg_version
    call puts
    call newline
    jmp after_command

; --------------------
; ECHO COMMAND
; --------------------
cmd_echo_exec:
    ; skip "echo "
    mov si, input_buffer
    add si, 5
    call puts
    call newline
    jmp after_command


; --------------------
; CLEAR COMMAND
; --------------------
cmd_clear_exec:
    call clear_screen
    call print_prompt
    jmp main_loop


; --------------------
; HELP COMMAND
; --------------------
cmd_help_exec:
    mov si, msg_help
    call puts
    call newline

after_command:
    mov byte [buf_len], 0
    call print_prompt
    jmp main_loop

; --------------------
; BACKSPACE KEY
; --------------------
handle_backspace:
    mov bl, [buf_len]
    cmp bl, 0
    je main_loop

    dec byte [buf_len]

    mov ah, 0x0E
    mov al, BACKSPACE
    int 10h
    mov al, ' '
    int 10h
    mov al, BACKSPACE
    int 10h

    jmp main_loop

; --------------------
; UTILITIES
; --------------------
print_prompt:
    mov si, msg_prompt
    call puts
    ret

newline:
    mov si, endl
    call puts
    ret

; --------------------
; strcmp
; AX = 1 if equal
; --------------------
strcmp:
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.equal:
    mov ax, 1
    ret
.not_equal:
    mov ax, 0
    ret

; --------------------
; puts DS:SI
; --------------------
puts:
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 10h
    jmp .loop
.done:
    ret

; --------------------
; Clear screen (BIOS)
; --------------------
clear_screen:
    mov ah, 0x00
    mov al, 0x03      ; 80x25 text mode
    int 10h
    ret

; --------------------
; strncmp for echo
; AX = 1 if buffer starts with "echo "
; --------------------
strncmp_echo:
    push si
    push di

    mov cx, 4
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    inc si
    inc di
    loop .loop

    ; must be followed by space
    mov al, [si]
    cmp al, ' '
    jne .not_equal

    mov ax, 1
    jmp .done

.not_equal:
    mov ax, 0

.done:
    pop di
    pop si
    ret


; --------------------
; DATA
; --------------------
msg_welcome db 'Welcome to jazzOS -- Ravi', ENDL, 0
msg_prompt  db 'jazzOS> ', 0
msg_unknown db 'Unknown command', 0
msg_version db 'jazzOS version 0.1 (real mode)', 0
msg_help    db 'Available commands:', ENDL, ' help', ENDL, ' clear', ENDL, ' version',ENDL, ' echo <text>', 0
endl        db ENDL, 0

cmd_help db 'help', 0
cmd_clear db 'clear', 0
cmd_version db 'version', 0
cmd_echo db 'echo', 0

input_buffer times BUFFER_SIZE db 0
buf_len     db 0
