; =============================================================================
; Project: Pong OS (Bare-Metal x86)
; Author: danko1122q
; Copyright (c) 2024 danko1122q
;
; License: MIT with Attribution.
; Modification and redistribution are permitted provided that the original 
; author is credited in all copies or substantial portions of the software.
; =============================================================================

bits 16
org 0x7E00

; --- Configuration Constants ---
%define PADDLE_HEIGHT 4
%define PADDLE_LEFT_X 3
%define PADDLE_RIGHT_X 76
%define BORDER_TOP_Y 0
%define BORDER_BOTTOM_Y 24
%define MAX_SCORE '9'

start_game:
    cli                 ; Clear interrupts during segment setup
    xor ax, ax
    mov ds, ax
    mov es, ax
    sti                 ; Restore interrupts

    ; Initialize Video Mode (80x25 Text Mode)
    mov ax, 0x0003
    int 0x10

    ; Hide Hardware Cursor to prevent flickering
    mov ah, 0x01
    mov cx, 0x2607
    int 0x10

    call draw_full_court

main_loop:
    ; Victory Condition Checks
    cmp byte [score_left], MAX_SCORE
    je game_over_p1
    cmp byte [score_right], MAX_SCORE
    je game_over_p2

    ; Timing Logic (BIOS Tick Counter)
    mov ax, 0
    int 0x1A            
    cmp dx, [last_tick]
    je main_loop
    mov [last_tick], dx

    ; Keyboard Input Handling
    mov ah, 0x01
    int 0x16
    jz .move_ball_logic 

    mov ah, 0x00
    int 0x16            
    
    cmp al, 27          ; ESC Key - Return to Boot Menu
    je exit_to_menu

    push ax
    call erase_paddles
    pop ax

    ; Paddle Movement Logic
    cmp al, 'w'
    je .p1_up
    cmp al, 's'
    je .p1_down
    cmp ah, 0x48        ; Arrow Up
    je .p2_up
    cmp ah, 0x50        ; Arrow Down
    je .p2_down

; --- Paddle Controls ---
.p1_up:
    cmp byte [paddle_left_y], 1
    jbe .move_ball_logic
    dec byte [paddle_left_y]
    jmp .move_ball_logic
.p1_down:
    mov bl, [paddle_left_y]
    add bl, PADDLE_HEIGHT
    cmp bl, 24
    jae .move_ball_logic
    inc byte [paddle_left_y]
    jmp .move_ball_logic
.p2_up:
    cmp byte [paddle_right_y], 1
    jbe .move_ball_logic
    dec byte [paddle_right_y]
    jmp .move_ball_logic
.p2_down:
    mov bl, [paddle_right_y]
    add bl, PADDLE_HEIGHT
    cmp bl, 24
    jae .move_ball_logic
    inc byte [paddle_right_y]

; --- Game Engine ---
.move_ball_logic:
    inc byte [frame_count]
    cmp byte [frame_count], 1
    jb .draw_everything
    mov byte [frame_count], 0
    call erase_ball
    call move_ball
    call check_collisions
    call draw_ball

.draw_everything:
    call draw_paddles
    call draw_scores
    call draw_center_line
    jmp main_loop

exit_to_menu:
    ; Hard Reboot via Keyboard Controller (Port 0x64)
    mov al, 0xFE
    out 0x64, al
    int 0x19            ; Fallback to BIOS warm reboot
    jmp $

; --- Game Over Screens ---
game_over_p1:
    mov si, msg_p1_win
    jmp display_game_over
game_over_p2:
    mov si, msg_p2_win
    jmp display_game_over

display_game_over:
    mov ax, 0x0600      ; Scroll window/Clear screen
    mov bh, 0x07
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    mov dh, 11
    mov dl, 33
    call set_cursor
    call print_yellow_string
    mov dh, 13
    mov dl, 22           ;position massage
    call set_cursor
    mov si, msg_restart
    call print_white_string

.wait_restart:
    mov ah, 0x00
    int 0x16
    cmp al, 'r'
    je .do_restart
    cmp al, 27
    je exit_to_menu
    jmp .wait_restart

.do_restart:
    mov byte [score_left], '0'
    mov byte [score_right], '0'
    jmp start_game

; --- Rendering Subroutines ---
set_cursor:
    mov ah, 0x02
    xor bh, bh
    int 0x10
    ret

print_yellow_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x09
    mov bl, 0x0E        ; Yellow text
    mov cx, 1
    int 0x10
    inc dl
    call set_cursor
    jmp print_yellow_string
.done:
    ret

print_white_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E        ; TTY output
    int 0x10
    jmp print_white_string
.done:
    ret

draw_full_court:
    mov ax, 0x0600
    mov bh, 0x07
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    call draw_borders
    ret

draw_borders:
    ; Horizontal borders
    mov dh, BORDER_TOP_Y
    mov dl, 1
    call set_cursor
    mov ax, 0x09CD
    mov cx, 78
    mov bl, 0x07
    int 0x10
    mov dh, BORDER_BOTTOM_Y
    mov dl, 1
    call set_cursor
    mov ax, 0x09CD
    mov cx, 78
    int 0x10
    ; Vertical borders
    mov dh, 1
.v_loop:
    mov dl, 0
    call set_cursor
    mov ax, 0x09BA
    mov cx, 1
    int 0x10
    mov dl, 79
    call set_cursor
    mov ax, 0x09BA
    mov cx, 1
    int 0x10
    inc dh
    cmp dh, 24
    jl .v_loop

    ; --- FIX: Expanded Corners for NASM Compatibility ---
    ; Top-Left
    mov dh, 0
    mov dl, 0
    call set_cursor
    mov ax, 0x09C9
    int 0x10

    ; Top-Right
    mov dh, 0
    mov dl, 79
    call set_cursor
    mov ax, 0x09BB
    int 0x10

    ; Bottom-Left
    mov dh, 24
    mov dl, 0
    call set_cursor
    mov ax, 0x09C8
    int 0x10

    ; Bottom-Right
    mov dh, 24
    mov dl, 79
    call set_cursor
    mov ax, 0x09BC
    int 0x10
    ret

draw_center_line:
    mov dh, 1
.mid:
    mov dl, 40
    call set_cursor
    mov al, '|'
    mov ah, 0x0E
    int 0x10
    add dh, 2
    cmp dh, 24
    jl .mid
    ret

erase_ball:
    mov dh, [ball_y]
    mov dl, [ball_x]
    cmp dh, 0
    je .s
    cmp dh, 24
    je .s
    call set_cursor
    mov al, ' '
    mov ah, 0x0E
    int 0x10
.s: ret

draw_ball:
    mov dh, [ball_y]
    mov dl, [ball_x]
    call set_cursor
    mov al, [ball_char]
    mov ah, 0x09
    mov bh, 0
    mov bl, 0x0E
    mov cx, 1
    int 0x10
    ret

erase_paddles:
    mov cx, PADDLE_HEIGHT
    mov dh, [paddle_left_y]
.e1: 
    push cx
    mov dl, PADDLE_LEFT_X
    call set_cursor
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    inc dh
    pop cx
    loop .e1
    mov cx, PADDLE_HEIGHT
    mov dh, [paddle_right_y]
.e2: 
    push cx
    mov dl, PADDLE_RIGHT_X
    call set_cursor
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    inc dh
    pop cx
    loop .e2
    ret

draw_paddles:
    mov cx, PADDLE_HEIGHT
    mov dh, [paddle_left_y]
.d1: 
    push cx
    mov dl, PADDLE_LEFT_X
    call set_cursor
    mov ax, 0x09DB
    mov bl, 0x0C        ; Red Player
    mov cx, 1
    int 0x10
    inc dh
    pop cx
    loop .d1
    mov cx, PADDLE_HEIGHT
    mov dh, [paddle_right_y]
.d2: 
    push cx
    mov dl, PADDLE_RIGHT_X
    call set_cursor
    mov ax, 0x09DB
    mov bl, 0x0A        ; Green Player
    mov cx, 1
    int 0x10
    inc dh
    pop cx
    loop .d2
    ret

draw_scores:
    mov dh, 1
    mov dl, 30
    call set_cursor
    mov al, [score_left]
    mov ah, 0x0E
    int 0x10
    mov dl, 50
    call set_cursor
    mov al, [score_right]
    mov ah, 0x0E
    int 0x10
    ret

move_ball:
    mov al, [ball_x]
    add al, [ball_dx]
    mov [ball_x], al
    mov al, [ball_y]
    add al, [ball_dy]
    mov [ball_y], al
    ret

check_collisions:
    ; Top/Bottom collision
    cmp byte [ball_y], 1
    jle .rev_y
    cmp byte [ball_y], 23
    jge .rev_y
    ; Left Paddle collision
    cmp byte [ball_x], PADDLE_LEFT_X + 1
    jne .cr
    mov al, [ball_y]
    cmp al, [paddle_left_y]
    jl .cr
    mov bl, [paddle_left_y]
    add bl, PADDLE_HEIGHT
    cmp al, bl
    jge .cr
    mov byte [ball_dx], 1
    ret
.cr:
    ; Right Paddle collision
    cmp byte [ball_x], PADDLE_RIGHT_X - 1
    jne .co
    mov al, [ball_y]
    cmp al, [paddle_right_y]
    jl .co
    mov bl, [paddle_right_y]
    add bl, PADDLE_HEIGHT
    cmp al, bl
    jge .co
    mov byte [ball_dx], -1
    ret
.co:
    ; Score Check
    cmp byte [ball_x], 1
    jle .wr
    cmp byte [ball_x], 78
    jge .wl
    ret
.rev_y: 
    neg byte [ball_dy]
    ret
.wr: 
    inc byte [score_right]
    call reset_ball
    ret
.wl: 
    inc byte [score_left]
    call reset_ball
    ret

reset_ball:
    mov byte [ball_x], 40
    mov byte [ball_y], 12
    neg byte [ball_dx]
    ret

; --- Data Section ---
ball_x db 40
ball_y db 12
ball_dx db 1
ball_dy db 1
ball_char db 0xDB 
paddle_left_y db 10
paddle_right_y db 10
score_left db '0'
score_right db '0'
frame_count db 0
last_tick dw 0
msg_p1_win db "PLAYER 1 WINS!", 0
msg_p2_win db "PLAYER 2 WINS!", 0
msg_restart db "Press 'R' to Restart or ESC to Menu", 0
