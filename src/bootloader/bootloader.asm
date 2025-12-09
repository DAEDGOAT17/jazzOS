; Tell NASM to assemble for 16-bit real mode and start at address 0x7c00
[org 0x7c00]

; ------------------------------------------------------------------------------
; FAT12 BOOT SECTOR (BIOS Parameter Block / Extended Boot Record)
; ------------------------------------------------------------------------------
  jmp short start
  nop
  db "MSWIN4.1"   ; 8-byte OEM Identifier
  dw 512         ; Bytes Per Sector (0x0200)
  db 1           ; Sectors Per Cluster
  dw 1           ; Reserved Sectors
  db 2           ; FAT Count
  dw 224         ; Directory Entry Count (0xE0)
  dw 2880        ; Total Number of Sectors (1.44MB floppy)
  db 0xF0        ; Media Descriptor Type (0xF0 for 3.5" floppy)
  dw 9           ; Sectors Per FAT
  dw 18          ; Sectors Per Track
  dw 2           ; Head Count
  dd 0           ; Hidden Sector Count
  dd 0           ; Large Sector Count
  db 0           ; Drive Number (0 for floppy)
  db 0           ; Reserved
  db 0x29        ; Extended Boot Signature (0x29 or 0x28)
  dd 0xDEADBEEF  ; Volume ID (Serial Number)
  db "PANKAJ0S    " ; 11-byte Volume Label (Padded with spaces)
  db "FAT12   "   ; 8-byte System ID (Padded with spaces)

; ------------------------------------------------------------------------------
; CODE START
; ------------------------------------------------------------------------------
start:
  ; Setup Stack
  mov bp, 0x7c00 ; Base pointer
  mov sp, bp     ; Stack pointer (stack grows down from 0x7c00)
  
  ; Save Drive Number (set by BIOS in DL)
  mov [boot_drive], dl 
  
  ; Jump to main logic
  jmp main

; ------------------------------------------------------------------------------
; MAIN LOGIC
; ------------------------------------------------------------------------------
main:
  ; Print "Hello world" (Used to verify the system is running)
  mov si, msg_hello
  call print_string
  
  ; Print "Reading from disk..."
  mov si, msg_read
  call print_string
  
  ; --- Disk Read Setup (To read Sector 2 into memory at 0x7E00:0000) ---
  mov ax, 0x7e00     ; Segment for data destination
  mov es, ax
  mov bx, 0x0000     ; Offset for data destination (ES:BX)
  
  mov cl, 1          ; Read 1 sector
  mov ax, 1          ; LBA = 1 (Sector 2, as LBA 0 is the boot sector)
  mov dl, [boot_drive] ; Drive number
  
  mov di, 3          ; Retry count = 3
  call disk_read     ; Call the disk read function

  ; Code for loading the rest of the kernel would go here...
  
  ; Final halt loop
  cli ; Disable interrupts
  hlt ; Halt the CPU

; ------------------------------------------------------------------------------
; LBA TO CHS CONVERSION FUNCTION
; ------------------------------------------------------------------------------
; Converts Logical Block Address (LBA) in AX to Cylinder-Head-Sector (CHS) in CX and DH.
; (LBA = (Cyl * HPC + Head) * SPT + (Sec - 1))
lba2chs:
  push dx          ; Save DX for later
  push ax          ; Save AX for later
  
  ; 1. Calculate Sector (Sec = (LBA % SPT) + 1)
  xor dx, dx       ; Clear DX (DX:AX is dividend for DIV)
  div word [SPT]   ; AX = LBA / SPT, DX = LBA % SPT
  
  inc dl           ; Sector numbers are 1-based, so add 1 to remainder (in DL)
  mov cl, dl       ; Move Sector (5 bits) to CL (bits 0-7 of CX)
  
  ; 2. Calculate Head (Head = (LBA / SPT) % HPC)
  xor dx, dx       ; Clear DX for next division
  div word [HPC]   ; AX = (LBA/SPT) / HPC (Cylinder), DX = (LBA/SPT) % HPC (Head)
  
  mov dh, dl       ; Move Head (in DL) to DH (Head Register)
  
  ; 3. Calculate Cylinder (Cyl = (LBA / SPT) / HPC)
  mov ch, al       ; Move Cylinder (8 bits in AL) to CH (High 8 bits of CX)
  
  shl ah, 6        ; Shift high 2 bits of Cylinder (in AH) left by 6
  or cl, ah        ; OR with CL to combine sector and high cylinder bits
  
  pop ax           ; Restore AX
  pop dx           ; Restore DX
  ret

; ------------------------------------------------------------------------------
; DISK READ FUNCTION
; ------------------------------------------------------------------------------
; Reads sectors from the disk using INT 0x13, AH=0x02, with a retry loop.
disk_read:
  push cx          ; Save CL (Sectors to Read) - overwritten by lba2chs
  push dx          ; Save DL (Drive Number) - overwritten by lba2chs
  
  call lba2chs     ; Convert LBA (in AX) to CHS (in CX, DH)
  
  pop dx           ; Restore DL
  pop cx           ; Restore CL
  
  ; Prepare AH and AL for INT 0x13, AH=0x02 (Read Sectors)
  mov al, cl       ; AL = Number of sectors to read
  mov ah, 0x02     ; AH = Function: Read Sectors

.retry:
  pusha            ; Save all registers before interrupt call
  
  stc              ; Set Carry Flag (to make checking easier)
  int 0x13         ; Call BIOS disk service
  jnc .done        ; If Carry Flag is NOT set (JNC), operation succeeded.
  
  popa             ; Restore registers for retry
  call disk_reset  ; Reset disk controller
  
  dec di           ; Decrement retry counter (DI should be set by caller)
  jnz .retry       ; If DI is not zero, retry

.error:
  jmp floppy_error ; Jump to the error routine

.done:
  popa             ; Restore registers
  ret

; ------------------------------------------------------------------------------
; DISK RESET FUNCTION
; ------------------------------------------------------------------------------
; Resets the disk controller using INT 0x13, AH=0x00.
disk_reset:
  push ax
  mov ah, 0x00     ; AH = 0x00 (Reset Disk System)
  int 0x13
  jnc .done        ; If Carry Flag is clear, successful
  jmp floppy_error ; On failure, jump to error
  
.done:
  pop ax
  ret

; ------------------------------------------------------------------------------
; ERROR & DATA SECTION
; ------------------------------------------------------------------------------
floppy_error:
  ; Simple error display (using print_string function)
  mov si, msg_error
  call print_string
  
  ; Wait for key press (INT 0x16, AH=0x00)
  mov ah, 0x00
  int 0x16
  
  ; Reboot the system
  jmp 0xFFFF:0x0000

; Helper for printing strings (from Part 1)
print_string:
  mov ah, 0x0e     ; AH=0x0E (Teletype Output)
.loop:
  lodsb          ; Load byte from SI into AL, increment SI
  cmp al, 0x00   ; Check for null terminator
  je .done       ; If null, finish
  int 0x10       ; Print character
  jmp .loop
.done:
  ret

; Variables and Constants
boot_drive db 0
SPT dw 18
HPC dw 2

; Messages
msg_hello db "Hello world", 0x0D, 0x0A, 0x00
msg_read db "Reading from disk...", 0x0D, 0x0A, 0x00
msg_error db "Floppy Error! Press any key to reboot...", 0x0D, 0x0A, 0x00

; ------------------------------------------------------------------------------
; BOOT SECTOR PADDING AND MAGIC NUMBER
; ------------------------------------------------------------------------------
; Pad the boot sector to 510 bytes (Total size must be 512 bytes)
times 510-($-$$) db 0
dw 0xAA55 ; Boot Sector Magic Number