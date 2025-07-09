; the bootloader loads all the bootable devices into the memory location of 0x7c00 and check for a signature with 0xaa55 if it fins the signature it starts executing form the start of the data segement so to get the bbotlaoder to work we need to write the signature to our baser loader memory address
ORG 0x7c00
BITS 16

main:
    MOV ax,0
    MOV ds , ax 
    MOV es , ax
    MOV ss , ax

    MOV sp , 0x7c00
    MOV si , os_boot_msg
    CALL print

    HLT


halt:
    JMP halt


print:
    PUSH si 
    PUSH ax 
    PUSH bx

print_loop:
    LODSB 
    OR al ,al
    JZ done_print

    MOV ah ,0x0e    ;this makes the print to come to screen
    MOV bh ,0
    INT 0x10

    JMP print_loop

done_print:
    POP bx
    POP ax
    POP si
    RET

os_boot_msg:
    DB 'os has successfully booted pankaj!' ,0x0D ,0x0A,0

TIMES 510-($-$$) DB 0
DW 0aa55h