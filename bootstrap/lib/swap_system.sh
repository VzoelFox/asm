#!/bin/bash
# Morph Swap System - Dual Swap Architecture
# Swap 1: Snapshot (checkpoint/rollback)
# Swap 2: Sandbox (isolated execution)

# Constants
SWAP_SNAPSHOT_SIZE=$((128 * 1024 * 1024))  # 128MB
SWAP_SANDBOX_SIZE=$((64 * 1024 * 1024))    # 64MB
SWAP_SNAPSHOT_COUNT=4                       # Max 4 snapshots
SWAP_SANDBOX_COUNT=8                        # Max 8 sandboxes

# Generate Assembly for Swap System
generate_swap_kernel() {
cat << 'ASMEOF'
; ===================================================================
; MORPH DUAL SWAP SYSTEM - Memory V2.1
; ===================================================================
; Architecture:
; - Main Heap: 256MB (existing bump allocator)
; - Snapshot Swap: 128MB × 4 slots = 512MB (checkpoint/rollback)
; - Sandbox Swap: 64MB × 8 slots = 512MB (isolated execution)
; ===================================================================

section .data
    ; Swap Configuration
    SNAPSHOT_SWAP_SIZE equ 134217728    ; 128MB
    SANDBOX_SWAP_SIZE  equ 67108864     ; 64MB
    MAX_SNAPSHOTS      equ 4
    MAX_SANDBOXES      equ 8

    ; Error Messages
    msg_swap_full db "Error: Snapshot swap full (max 4)", 10, 0
    len_swap_full equ $ - msg_swap_full

    msg_sandbox_full db "Error: Sandbox swap full (max 8)", 10, 0
    len_sandbox_full equ $ - msg_sandbox_full

section .bss
    ; Snapshot Swap Slots (4 × 128MB)
    snapshot_swap_ptrs  resq 4      ; Pointers to mmap regions
    snapshot_swap_sizes resq 4      ; Used sizes
    snapshot_swap_active resb 4     ; Active flags (1=used, 0=free)
    snapshot_count      resq 1      ; Current snapshot count

    ; Sandbox Swap Slots (8 × 64MB)
    sandbox_swap_ptrs   resq 8      ; Pointers to mmap regions
    sandbox_swap_sizes  resq 8      ; Used sizes
    sandbox_swap_active resb 8      ; Active flags
    sandbox_count       resq 1      ; Current sandbox count

    ; Timestamp tracking (for daemon cleaner)
    snapshot_timestamps resq 4      ; Last access time
    sandbox_timestamps  resq 8      ; Last access time

section .text

; ===================================================================
; SNAPSHOT SWAP FUNCTIONS
; ===================================================================

; sys_snapshot_create: Create memory snapshot
; Output: RAX = snapshot_id (0-3), or -1 if full
sys_snapshot_create:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Find free slot
    xor rbx, rbx
.find_slot:
    cmp rbx, MAX_SNAPSHOTS
    jge .no_slot

    cmp byte [snapshot_swap_active + rbx], 0
    je .found_slot

    inc rbx
    jmp .find_slot

.no_slot:
    mov rsi, msg_swap_full
    mov rdx, len_swap_full
    call sys_write_stderr
    mov rax, -1
    jmp .done

.found_slot:
    ; Allocate swap memory via mmap
    mov rax, 9              ; SYS_MMAP
    mov rdi, 0              ; addr = 0
    mov rsi, SNAPSHOT_SWAP_SIZE
    mov rdx, 3              ; PROT_READ | PROT_WRITE
    mov r10, 34             ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    mov r9, 0
    syscall

    cmp rax, 0
    jl .mmap_fail

    ; Save to slot
    mov [snapshot_swap_ptrs + rbx*8], rax
    mov byte [snapshot_swap_active + rbx], 1

    ; Get current timestamp
    push rax
    call sys_get_timestamp
    mov [snapshot_timestamps + rbx*8], rax
    pop rax

    ; Copy current heap to snapshot
    push rbx
    mov rdi, rax                        ; dest = snapshot
    mov rsi, [heap_start_ptr]           ; src = heap
    mov rcx, [heap_current_ptr]
    sub rcx, rsi                        ; size = current - start
    mov [snapshot_swap_sizes + rbx*8], rcx
    call sys_memcpy
    pop rbx

    ; Increment count
    inc qword [snapshot_count]

    ; Return snapshot ID
    mov rax, rbx
    jmp .done

.mmap_fail:
    mov rax, -1

.done:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; sys_snapshot_restore: Restore from snapshot
; Input: RAX = snapshot_id
; Output: RAX = 1 success, 0 fail
sys_snapshot_restore:
    push rbx
    push rcx
    push rdi
    push rsi

    mov rbx, rax

    ; Validate ID
    cmp rbx, MAX_SNAPSHOTS
    jge .invalid

    cmp byte [snapshot_swap_active + rbx], 0
    je .invalid

    ; Restore heap from snapshot
    mov rsi, [snapshot_swap_ptrs + rbx*8]  ; src = snapshot
    mov rdi, [heap_start_ptr]              ; dest = heap
    mov rcx, [snapshot_swap_sizes + rbx*8] ; size
    call sys_memcpy

    ; Restore heap_current_ptr
    mov rax, [heap_start_ptr]
    add rax, rcx
    mov [heap_current_ptr], rax

    ; Update timestamp
    push rbx
    call sys_get_timestamp
    mov [snapshot_timestamps + rbx*8], rax
    pop rbx

    mov rax, 1
    jmp .done_restore

.invalid:
    mov rax, 0

.done_restore:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; sys_snapshot_free: Free snapshot slot
; Input: RAX = snapshot_id
sys_snapshot_free:
    push rbx
    push rdi
    push rsi

    mov rbx, rax

    ; Validate
    cmp rbx, MAX_SNAPSHOTS
    jge .done_free

    cmp byte [snapshot_swap_active + rbx], 0
    je .done_free

    ; munmap
    mov rax, 11             ; SYS_MUNMAP
    mov rdi, [snapshot_swap_ptrs + rbx*8]
    mov rsi, SNAPSHOT_SWAP_SIZE
    syscall

    ; Clear slot
    mov qword [snapshot_swap_ptrs + rbx*8], 0
    mov qword [snapshot_swap_sizes + rbx*8], 0
    mov byte [snapshot_swap_active + rbx], 0
    mov qword [snapshot_timestamps + rbx*8], 0

    dec qword [snapshot_count]

.done_free:
    pop rsi
    pop rdi
    pop rbx
    ret

; ===================================================================
; SANDBOX SWAP FUNCTIONS
; ===================================================================

; sys_sandbox_create: Create isolated sandbox
; Output: RAX = sandbox_id (0-7), or -1 if full
sys_sandbox_create:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Find free slot
    xor rbx, rbx
.find_sandbox:
    cmp rbx, MAX_SANDBOXES
    jge .no_sandbox

    cmp byte [sandbox_swap_active + rbx], 0
    je .found_sandbox

    inc rbx
    jmp .find_sandbox

.no_sandbox:
    mov rsi, msg_sandbox_full
    mov rdx, len_sandbox_full
    call sys_write_stderr
    mov rax, -1
    jmp .done_sandbox

.found_sandbox:
    ; Allocate sandbox via mmap
    mov rax, 9
    mov rdi, 0
    mov rsi, SANDBOX_SWAP_SIZE
    mov rdx, 3
    mov r10, 34
    mov r8, -1
    mov r9, 0
    syscall

    cmp rax, 0
    jl .sandbox_fail

    ; Save slot
    mov [sandbox_swap_ptrs + rbx*8], rax
    mov byte [sandbox_swap_active + rbx], 1
    mov qword [sandbox_swap_sizes + rbx*8], 0

    ; Timestamp
    push rax
    push rbx
    call sys_get_timestamp
    pop rbx
    mov [sandbox_timestamps + rbx*8], rax
    pop rax

    inc qword [sandbox_count]

    mov rax, rbx
    jmp .done_sandbox

.sandbox_fail:
    mov rax, -1

.done_sandbox:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; sys_sandbox_alloc: Allocate in sandbox
; Input: RDI = sandbox_id, RAX = size
; Output: RAX = pointer in sandbox
sys_sandbox_alloc:
    push rbx
    push rcx
    push rdx

    mov rbx, rdi    ; sandbox_id

    ; Validate
    cmp rbx, MAX_SANDBOXES
    jge .invalid_sandbox

    cmp byte [sandbox_swap_active + rbx], 0
    je .invalid_sandbox

    ; Align size
    add rax, 7
    and rax, -8

    ; Check bounds
    mov rcx, [sandbox_swap_sizes + rbx*8]
    mov rdx, rcx
    add rdx, rax
    cmp rdx, SANDBOX_SWAP_SIZE
    jg .sandbox_oom

    ; Calculate pointer
    mov rdx, [sandbox_swap_ptrs + rbx*8]
    add rdx, rcx

    ; Update size
    add rcx, rax
    mov [sandbox_swap_sizes + rbx*8], rcx

    ; Update timestamp
    push rdx
    push rbx
    call sys_get_timestamp
    pop rbx
    mov [sandbox_timestamps + rbx*8], rax
    pop rdx

    mov rax, rdx
    jmp .done_sballoc

.invalid_sandbox:
.sandbox_oom:
    mov rax, 0

.done_sballoc:
    pop rdx
    pop rcx
    pop rbx
    ret

; sys_sandbox_free: Free sandbox
; Input: RAX = sandbox_id
sys_sandbox_free:
    push rbx
    push rdi
    push rsi

    mov rbx, rax

    cmp rbx, MAX_SANDBOXES
    jge .done_sbfree

    cmp byte [sandbox_swap_active + rbx], 0
    je .done_sbfree

    ; munmap
    mov rax, 11
    mov rdi, [sandbox_swap_ptrs + rbx*8]
    mov rsi, SANDBOX_SWAP_SIZE
    syscall

    ; Clear
    mov qword [sandbox_swap_ptrs + rbx*8], 0
    mov qword [sandbox_swap_sizes + rbx*8], 0
    mov byte [sandbox_swap_active + rbx], 0
    mov qword [sandbox_timestamps + rbx*8], 0

    dec qword [sandbox_count]

.done_sbfree:
    pop rsi
    pop rdi
    pop rbx
    ret

; ===================================================================
; UTILITY FUNCTIONS
; ===================================================================

sys_write_stderr:
    push rax
    mov rax, 1
    mov rdi, 2
    syscall
    pop rax
    ret

ASMEOF
}

# Export function
export -f generate_swap_kernel
