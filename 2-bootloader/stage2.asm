
bits 16
org 0x8000

start:
    mov si, message

print:
    lodsb
    test al, al
    jz done

    mov ah, 0x0E
    int 0x10
    jmp print

done:
    jmp $

message:
    db "Hello from Stage 2!", 0

times 512-($-$$) db 0
