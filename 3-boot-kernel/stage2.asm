
bits 16
org 0x8000

start:
    ; Use segment zero for our data addresses
    xor ax, ax
    mov ds, ax

    ; Save boot drive
    mov [boot_drive], dl

    ; Load Kernel from disk sector 3 into 0x10000
    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 3
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc error

    ; Enter 32-bit Protected Mode
    cli
    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:protected_start

error:
    mov ah, 0x0E
    mov al, '2'
    int 0x10
    jmp $

bits 32

protected_start:
    ; Configure 32-bit data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Prepare a stack for C
    mov esp, 0x90000

    ; Execute the C kernel at 0x10000
    mov eax, 0x10000
    call eax

hang:
    hlt
    jmp hang

bits 16

boot_drive:
    db 0

; Minimal flat 32-bit segment descriptors
gdt_start:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 512-($-$$) db 0
