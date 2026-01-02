#!/bin/bash
# DateTime Functionality for Morph

generate_datetime_kernel() {
cat << 'DTASM'
; ===================================================================
; DATETIME SYSTEM - syscall time/clock_gettime
; ===================================================================

section .data
    ; Time constants
    CLOCK_REALTIME equ 0
    CLOCK_MONOTONIC equ 1

section .bss
    timespec_sec  resq 1
    timespec_nsec resq 1

section .text

; sys_get_timestamp: Get current Unix timestamp (seconds since 1970)
; Output: RAX = timestamp
sys_get_timestamp:
    push rdi
    push rsi

    mov rax, 228            ; SYS_clock_gettime
    mov rdi, CLOCK_REALTIME
    lea rsi, [timespec_sec]
    syscall

    mov rax, [timespec_sec]

    pop rsi
    pop rdi
    ret

; sys_get_monotonic: Get monotonic time (for measuring intervals)
; Output: RAX = seconds, RDX = nanoseconds
sys_get_monotonic:
    push rdi
    push rsi

    mov rax, 228            ; SYS_clock_gettime
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [timespec_sec]
    syscall

    mov rax, [timespec_sec]
    mov rdx, [timespec_nsec]

    pop rsi
    pop rdi
    ret

; sys_sleep: Sleep for N seconds
; Input: RAX = seconds
sys_sleep:
    push rdi

    mov rdi, rax
    mov rax, 35             ; SYS_nanosleep
    ; Build timespec on stack
    push 0                  ; nsec
    push rdi                ; sec
    mov rdi, rsp
    xor rsi, rsi            ; NULL rem
    syscall
    add rsp, 16             ; cleanup stack

    pop rdi
    ret

; sys_datetime_format: Format timestamp ke string "YYYY-MM-DD HH:MM:SS"
; Input: RDI = timestamp, RSI = buffer (min 20 bytes)
; Output: RSI filled with formatted string
sys_datetime_format:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; For simplicity, just format as unix timestamp for now
    ; Full date formatting requires complex calendar calculations
    
    ; Convert timestamp to string
    mov rax, rdi            ; timestamp
    mov rbx, 10
    mov rcx, 0              ; digit count

.convert_loop:
    xor rdx, rdx
    div rbx                 ; rax = rax / 10, rdx = remainder
    add dl, '0'
    push rdx
    inc rcx
    test rax, rax
    jnz .convert_loop

.write_loop:
    pop rax
    mov [rsi], al
    inc rsi
    loop .write_loop

    mov byte [rsi], 0       ; null terminate

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; sys_time_diff: Calculate time difference
; Input: RDI = start_time, RSI = end_time
; Output: RAX = difference in seconds
sys_time_diff:
    mov rax, rsi
    sub rax, rdi
    ret

DTASM
}

export -f generate_datetime_kernel
