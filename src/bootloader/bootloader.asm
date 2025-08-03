; the bootloader loads all the bootable devices into the memory location of 0x7c00 and check for a signature with 0xaa55 if it fins the signature it starts executing form the start of the data segement so to get the bbotlaoder to work we need to write the signature to our baser loader memory address
ORG 0x7c00
BITS 16

JMP SHORT main ;jmps short only jmps inside the file
NOP

bdb_oem: DB "MSWIN4.1"       ;SIZE 8
bdb_bytes_per_sectors: DW 512
bdb_sectors_per_cluster: DB 1
bdb_reserved_sectors:  DW 1
bdb_fat_count:     DB 2
bdb_dir_entries_count: DW  0x0E0
bdb_total_sectors:     DW  2880
bdb_media_descriptor_type: DB 0xF0
bdb_sectors_per_fat:   DW  9
bdb_sectors_per_track: DW 18 
bdb_heads:    DW 2
bdb_hidden_sectors: DD 0
bdb_large_sector_count: DD 0
;extended boot record 
ebr_drive_number:  DB 0
                    DB 0
ebr_signature:      DB 0x29
ebr_volume_id:      DB 0x12,0x34,0x56,0x78
ebr_volume_label:   DB  "PANKAJ0S0_1"     ;SIZE 11
ebr_system_id:      DB  "FAT12   "      ;SIZE 8



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

main:
    MOV ax,0
    MOV ds , ax 
    MOV es , ax
    MOV ss , ax

    MOV sp , 0x7c00

    MOV [ebr_drive_number] ,dl
    MOV ax ,1 
    MOV cl ,1
    MOV bx , 0x7E00
    CALL disk_read


    MOV si , os_boot_msg
    CALL print

    CLI
    HLT

fail_disk_read:
    MOV si ,read_faliure
    CALL print
    JMP wait_key_reboot

wait_key_reboot:
    MOV ah,0
    INT 0x16  ;this waits for a key press
    JMP 0FFFFh:0
    HLT


halt:
    CLI 
    HLT


lba_to_chs:
    PUSH ax 
    PUSH dx

    XOR dx,dx
    DIV word [bdb_sectors_per_track] ; (LBA % sectros per track )+1  first formulae gives us sector as lba is ax and exa/bdb_sec_per_track gives is the sectors as the modulous is given in dx by std div
    INC dx  ; sector
    MOV cx,dx

    XOR dx,dx  ;setting the dx to zero
    DIV word [bdb_heads]
    
    MOV dh,dl   ; head 
    MOV ch ,al 
    SHL ah , 6
    OR cl ,ah    ; cylinder

    POP ax 
    MOV dl ,al
    POP ax

    RET


disk_read:
    PUSH ax 
    PUSH bx 
    PUSH cx 
    PUSH dx
    PUSH di

    CALL lba_to_chs
    POP ax

    MOV ah,02h
    MOV di ,3 ; counter

retry:
    PUSHA
    STC  ;so we retry assuming faliure 
    INT 13h ;calling the read sector disk interupt
    JNC done_read  ;if no carry calling the disk read
    POPA

    CALL disk_reset  ;if error then calling the disk reset
    DEC di  ; decrese the carry counter 
    TEST di ,di   ;check teh value of di == 0
    JNZ retry   ; if not then retry left , try again

fail:
    JMP fail_disk_read

done_read:
    POP di
    POP dx
    POP cx
    POP bx
    POP ax
    RET

disk_reset:
    PUSHA
    MOV ah,0
    STC 
    INT 13h
    JC fail_disk_read
    POPA
    RET


os_boot_msg:
    DB 'os has successfully booted pankaj!' ,0x0D ,0x0A,0

read_faliure:
    DB 'failed to read disk pankaj !' ,0x0D, 0X0A ,0

TIMES 510-($-$$) DB 0
DW 0xAA55
