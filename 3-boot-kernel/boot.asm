
bits 16
org 0x7C00

start:
    ; Initialize segment registers and stack
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Save the boot drive
    mov [boot_drive], dl

    ; Load Stage 2 from disk sector 2
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, 0x8000
    int 0x13
    jc error

    ; Pass boot drive and execute Stage 2
    mov dl, [boot_drive]
    jmp 0x0000:0x8000

error:
    mov ah, 0x0E
    mov al, '1'
    int 0x10
    jmp $

boot_drive:
    db 0

times 510-($-$$) db 0
dw 0xAA55
