bits 16                 ; Generate 16-bit instructions (BIOS starts in real mode)
org 0x7C00              ; BIOS loads the boot sector at physical address 0x7C00

start:
    xor ax, ax          ; Set AX = 0
    mov ds, ax          ; Set DS = 0 so data addresses match our ORG

    mov si, message     ; SI points to the beginning of our string

print:
    lodsb               ; Load byte at DS:SI into AL, then advance SI
    test al, al         ; Check whether AL is 0 (end of string)
    jz done             ; If AL == 0, stop printing

    mov ah, 0x0E        ; Select BIOS teletype output service
    int 0x10            ; Call BIOS to print the character in AL
    jmp print           ; Repeat for the next character

done:
    jmp done            ; Infinite loop to prevent executing data as code

message:
    db "Hello, OS!", 0   ; Null-terminated string (0 marks the end)

times 510-($-$$) db 0   ; Pad with zeros until byte offset 510
dw 0xAA55               ; Boot signature: bytes 55 AA at offsets 510–511
