bits 16
org 0x7C00

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl

    ; Load game.bin (15 sektor) ke 0x0000:0x7E00
    mov ah, 0x02
    mov al, 15
    mov ch, 0
    mov dh, 0
    mov cl, 2
    mov dl, [boot_drive]
    mov bx, 0x7E00
    int 0x13
    jc load_error

    jmp 0x0000:0x7E00

load_error:
    jmp $

boot_drive db 0
times 510-($-$$) db 0
dw 0xAA55
