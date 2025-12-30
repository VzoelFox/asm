section .data
    msg_0 db "Halo dari Morph!", 10
    len_0 equ $ - msg_0

section .text
    global _start

_start:
    ; cetak string msg_0
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, msg_0     ; buffer
    mov rdx, len_0 ; length
    syscall
    ; Exit program
    mov rax, 60
    xor rdi, rdi
    syscall
