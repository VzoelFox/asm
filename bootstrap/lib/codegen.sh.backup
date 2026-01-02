# Codegen: Generates NASM Assembly for Linux x86-64

# Global State
STR_COUNT=0
LBL_COUNT=0
declare -a BSS_VARS
declare -a IF_STACK         # Stack for End Labels
declare -a IF_CHECK_STACK   # Stack for Next Check Labels (Else/ElseIf target)

init_codegen() {
    cat <<EOF
section .data
    newline db 10, 0
    ; --- Memory V2 Constants ---
    HEAP_CHUNK_SIZE equ 268435456 ; 256MB Chunk Size

    PROT_READ       equ 0x1
    PROT_WRITE      equ 0x2
    MAP_PRIVATE     equ 0x02
    MAP_ANONYMOUS   equ 0x20

    SYS_MMAP        equ 9
    SYS_MUNMAP      equ 11
    SYS_OPEN        equ 2
    SYS_CLOSE       equ 3

    ; Error Messages
    msg_oom db "Fatal: Out of Memory (Heap Exhausted)", 10, 0
    len_msg_oom equ $ - msg_oom

    msg_heap_fail db "Fatal: Heap Initialization Failed (mmap error)", 10, 0
    len_msg_heap_fail equ $ - msg_heap_fail

section .text
    global _start

_start:
    ; Initialize stack frame if needed
    mov rbp, rsp

    ; --- Get argc and argv ---
    ; Stack layout at _start:
    ; [RSP]    = argc
    ; [RSP+8]  = argv[0]
    ; [RSP+16] = argv[1] ...
    mov rdi, [rsp]      ; rdi = argc
    lea rsi, [rsp+8]    ; rsi = argv pointer

    ; --- Memory V2 Initialization ---
    push rdi
    push rsi
    call sys_init_heap
    pop rsi
    pop rdi

    ; --- Save to Global Variables ---
    ; We assume 'var global_argc' and 'var global_argv' are declared in Morph
    ; which generates 'var_global_argc' and 'var_global_argv' labels.
    mov [var_global_argc], rdi
    mov [var_global_argv], rsi

    ; Call entry point
    call mulai

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

; --- Helper Functions ---

; sys_panic: Prints error to stderr (fd=2) and exits with code 1
; Input: RSI = message ptr, RDX = length
sys_panic:
    mov rax, 1      ; sys_write
    mov rdi, 2      ; stderr
    syscall

    mov rax, 60     ; sys_exit
    mov rdi, 1      ; status = 1
    syscall
    ret

; sys_init_heap: Allocates the first 256MB chunk
sys_init_heap:
    push rdi
    push rsi
    push rdx
    push r10
    push r8
    push r9
    push rax

    ; mmap(0, 256MB, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
    mov rax, SYS_MMAP
    mov rdi, 0                  ; hint = 0
    mov rsi, HEAP_CHUNK_SIZE    ; length
    mov rdx, 3                  ; PROT_READ | PROT_WRITE
    mov r10, 34                 ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1                  ; fd = -1
    mov r9, 0                   ; offset = 0
    syscall

    ; Check for error (RAX < 0)
    cmp rax, 0
    jl .init_fail

    ; Save pointers
    mov [heap_start_ptr], rax   ; Start of the chunk
    mov [heap_current_ptr], rax ; Current bump pointer

    ; Calculate end
    add rax, HEAP_CHUNK_SIZE
    mov [heap_end_ptr], rax     ; End of the chunk

    pop rax
    pop r9
    pop r8
    pop r10
    pop rdx
    pop rsi
    pop rdi
    ret

.init_fail:
    mov rsi, msg_heap_fail
    mov rdx, len_msg_heap_fail
    call sys_panic
    ret ; Never reached

; sys_strcmp: Compare two strings (RSI, RDX)
; Output: RAX (1 if equal, 0 if not)
sys_strcmp:
    push rsi
    push rdx
    push rbx
    push rcx

.loop:
    mov al, [rsi]
    mov bl, [rdx]

    cmp al, bl
    jne .not_equal

    test al, al
    jz .equal       ; Reached null terminator and they are equal

    inc rsi
    inc rdx
    jmp .loop

.not_equal:
    mov rax, 0
    jmp .done

.equal:
    mov rax, 1

.done:
    pop rcx
    pop rbx
    pop rdx
    pop rsi
    ret

; print_string_ptr: Prints null-terminated string pointed by RSI
print_string_ptr:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rax

    ; Calculate length using scasb
    mov rdi, rsi    ; rdi = string start
    xor rax, rax    ; rax = 0 (search for null)
    mov rcx, -1     ; unlimited scan
    repne scasb     ; scan

    not rcx         ; rcx = -length - 2 (roughly)
    dec rcx         ; adjust

    mov rdx, rcx    ; length

    mov rax, 1      ; sys_write
    mov rdi, 1      ; stdout
    ; RSI is already buffer
    syscall

    call print_newline

    pop rax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; sys_alloc: Allocates N bytes from dynamic heap (V2)
; Input: RAX = size
; Output: RAX = pointer
sys_alloc:
    push rbx
    push rdx
    push rcx

    ; Align size to 8 bytes
    add rax, 7
    and rax, -8

    mov rbx, [heap_current_ptr]  ; Current pointer

    ; Calculate potential new pointer
    mov rcx, rbx
    add rcx, rax                ; rcx = new_ptr (potential)

    ; Check bounds
    mov rdx, [heap_end_ptr]
    cmp rcx, rdx
    jg .out_of_memory

    ; Success: update bump pointer
    mov [heap_current_ptr], rcx

    ; Return old pointer (rbx)
    mov rax, rbx

    pop rcx
    pop rdx
    pop rbx
    ret

.out_of_memory:
    mov rsi, msg_oom
    mov rdx, len_msg_oom
    call sys_panic
    ; Never reached
    mov rax, 0
    pop rcx
    pop rdx
    pop rbx
    ret

; sys_mem_checkpoint: Saves current heap pointer (returns it in RAX)
sys_mem_checkpoint:
    mov rax, [heap_current_ptr]
    ret

; sys_mem_rollback: Restores heap pointer from RAX
; Input: RAX = saved_heap_ptr
sys_mem_rollback:
    ; Safety Check: Rollback ptr must be >= start_ptr AND <= end_ptr
    mov rbx, [heap_start_ptr]
    cmp rax, rbx
    jl .invalid_rollback

    mov rbx, [heap_end_ptr]
    cmp rax, rbx
    jg .invalid_rollback

    ; Perform Rollback
    mov [heap_current_ptr], rax
    mov rax, 1 ; Success
    ret

.invalid_rollback:
    mov rax, 0 ; Fail
    ret

; sys_mem_rewind: Same as rollback, alias
sys_mem_rewind:
    jmp sys_mem_rollback

; sys_reset_memory: Resets the arena pointer to the start (Snapshot Cleanup)
sys_reset_memory:
    push rax
    mov rax, [heap_start_ptr]
    mov [heap_current_ptr], rax
    pop rax
    ret

; sys_free_memory: Returns the chunk to OS (Daemon Collector support)
sys_free_memory:
    push rax
    push rdi
    push rsi

    mov rax, SYS_MUNMAP
    mov rdi, [heap_start_ptr]
    mov rsi, HEAP_CHUNK_SIZE
    syscall

    ; Clear pointers to avoid use-after-free
    mov qword [heap_start_ptr], 0
    mov qword [heap_current_ptr], 0
    mov qword [heap_end_ptr], 0

    pop rsi
    pop rdi
    pop rax
    ret

; sys_write_fd: Write buffer to FD
; Input: RDI = fd, RSI = buffer_ptr, RDX = length
; Output: RAX = bytes_written
sys_write_fd:
    push rdi
    push rsi
    push rdx

    mov rax, 1      ; sys_write
    ; RDI is fd
    ; RSI is buffer
    ; RDX is length
    syscall

    pop rdx
    pop rsi
    pop rdi
    ret

; sys_strlen: Calculates length of null-terminated string
; Input: RSI = string ptr
; Output: RAX = length
sys_strlen:
    push rcx
    push rdi

    mov rdi, rsi
    xor rax, rax
    mov rcx, -1
    repne scasb
    not rcx
    dec rcx
    mov rax, rcx

    pop rdi
    pop rcx
    ret

; sys_memcpy: Copies bytes
; Input: RDI = dest, RSI = src, RCX = count
sys_memcpy:
    push rax
    push rcx
    push rsi
    push rdi

    rep movsb

    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; sys_str_concat: Concatenates two strings
; Input: RSI = str1, RDX = str2
; Output: RAX = new string ptr
sys_str_concat:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8 ; len1
    push r9 ; len2

    ; 1. Calc len1
    call sys_strlen
    mov r8, rax

    ; 2. Calc len2
    push rsi
    mov rsi, rdx
    call sys_strlen
    mov r9, rax
    pop rsi

    ; 3. Total size = len1 + len2 + 1
    mov rax, r8
    add rax, r9
    inc rax

    ; 4. Alloc
    call sys_alloc
    mov rbx, rax    ; dest ptr

    ; 5. Copy str1
    mov rdi, rbx
    mov rcx, r8
    call sys_memcpy

    ; 6. Copy str2
    lea rdi, [rbx + r8]
    mov rsi, rdx
    mov rcx, r9
    call sys_memcpy

    ; 7. Null terminate
    mov rdi, rbx
    add rdi, r8
    add rdi, r9
    mov byte [rdi], 0

    ; Return ptr
    mov rax, rbx

    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; sys_read: Reads N bytes from FD (default stdin if RDI not set, but wait, Morph calling convention)
; Helper Wrapper: sys_read_fd(fd, size)
; Input: RDI = fd, RSI = size
; Output: RAX = buffer_pointer, RDX = bytes_read
sys_read_fd:
    push rbx
    push rcx
    push rdi  ; Save fd
    push rsi  ; Save size

    ; 1. Allocate buffer
    mov rax, rsi    ; size
    call sys_alloc  ; rax = buffer_pointer
    mov rbx, rax    ; rbx = buffer_pointer

    pop rsi         ; size (count)
    pop rdi         ; fd

    ; 2. Syscall Read
    push rbx        ; Save buffer ptr
    mov rax, 0      ; sys_read
    mov rdx, rsi    ; count
    mov rsi, rbx    ; buf
    ; RDI is already fd
    syscall

    ; RAX now has bytes read
    pop rbx         ; Restore buffer ptr

    ; Null-terminate
    cmp rax, 0
    jl .read_error
    mov byte [rbx + rax], 0

    mov rdx, rax    ; Return bytes read in RDX
    mov rax, rbx    ; Return buffer ptr in RAX

    pop rcx
    pop rbx
    ret

.read_error:
    mov rax, 0
    pop rcx
    pop rbx
    ret

; sys_read: Legacy wrapper for stdin
; Input: RAX = max_size
; Output: RAX = buffer_pointer
sys_read:
    push rdi
    push rsi
    push rdx

    mov rsi, rax ; size
    mov rdi, 0   ; stdin
    call sys_read_fd

    pop rdx
    pop rsi
    pop rdi
    ret

; sys_open: Open file
; Input: RSI = filename_ptr, RDX = flags (0=RDONLY)
; Output: RAX = fd
sys_open:
    push rdi
    push rsi
    push rdx

    mov rax, 2      ; sys_open
    mov rdi, rsi    ; filename
    mov rsi, rdx    ; flags
    mov rdx, 0      ; mode (ignored for read)
    syscall

    pop rdx
    pop rsi
    pop rdi
    ret

; sys_close: Close file
; Input: RDI = fd
sys_close:
    push rax
    push rdi

    mov rax, 3      ; sys_close
    ; RDI is fd
    syscall

    pop rdi
    pop rax
    ret

; print_string: Expects address in RSI, length in RDX
print_string:
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall
    ret

; print_newline:
print_newline:
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    ret

; print_int: Expects integer in RAX
print_int:
    push rbp
    mov rbp, rsp
    sub rsp, 32         ; Reserve buffer space

    cmp rax, 0
    jne .check_sign

    ; Print '0'
    mov byte [rsp+30], '0'
    lea rsi, [rsp+30]
    mov rdx, 1
    call print_string
    leave
    ret

.check_sign:
    mov rbx, 31         ; Buffer index (start from end)

    ; Check if negative
    test rax, rax
    jns .convert_loop

    ; It is negative
    neg rax             ; Make positive
    push rax            ; Save value

    ; Print '-' immediately
    mov byte [rsp+16], '-'  ; Temporary scratch for char
    lea rsi, [rsp+16]
    mov rdx, 1
    push rcx ; Save regs used by syscall
    mov rax, 1
    mov rdi, 1
    syscall
    pop rcx

    pop rax             ; Restore positive value

.convert_loop:
    mov rcx, 10
    xor rdx, rdx
    div rcx             ; RAX / 10 -> RAX quot, RDX rem
    add dl, '0'
    mov [rsp+rbx], dl
    dec rbx
    test rax, rax
    jnz .convert_loop

    ; Print buffer
    lea rsi, [rsp+rbx+1] ; Start of string
    mov rdx, 31
    sub rdx, rbx        ; Length

    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall

    leave
    ret

; --- JSON Primitive Parsers (Kernel Level) ---

; sys_json_skip_whitespace: Skips whitespace chars (space, tab, newline)
; Input: RSI = buffer_ptr
; Output: RSI = new_buffer_ptr (at first non-whitespace)
sys_json_skip_whitespace:
    push rax
.skip_loop:
    mov al, [rsi]
    cmp al, 32  ; space
    je .next
    cmp al, 9   ; tab
    je .next
    cmp al, 10  ; newline
    je .next
    cmp al, 13  ; CR
    je .next

    ; Not whitespace
    jmp .done_skip

.next:
    inc rsi
    jmp .skip_loop

.done_skip:
    pop rax
    ret

; sys_json_parse_string: Parses "quoted string" to a new allocated buffer
; Input: RSI = buffer_ptr (points to opening quote or content)
; Output: RAX = new_string_ptr, RSI = buffer_ptr (after closing quote)
sys_json_parse_string:
    push rbx
    push rcx
    push rdx

    ; Check for opening quote
    cmp byte [rsi], 34 ; "
    jne .not_quote
    inc rsi ; Skip opening quote

.not_quote:
    mov rbx, rsi ; Save start of content

    ; Scan for length
    xor rcx, rcx
.scan_len:
    mov al, [rsi]
    cmp al, 34 ; "
    je .found_end
    cmp al, 0
    je .error_unterminated
    inc rsi
    inc rcx
    jmp .scan_len

.found_end:
    ; rcx = length of content
    ; Alloc new buffer
    mov rax, rcx
    inc rax ; +1 for null
    push rsi ; Save current position (closing quote)
    push rcx ; Save length

    call sys_alloc ; RAX = new buffer

    pop rcx ; Restore length
    pop rsi ; Restore closing quote pos

    ; Copy content
    ; dest = RAX, src = RBX, len = RCX
    push rdi
    push rsi

    mov rdi, rax
    mov rsi, rbx
    rep movsb

    mov byte [rdi], 0 ; Null terminate

    pop rsi
    pop rdi

    inc rsi ; Move past closing quote
    ; RAX already has new pointer

    pop rdx
    pop rcx
    pop rbx
    ret

.error_unterminated:
    mov rax, 0
    pop rdx
    pop rcx
    pop rbx
    ret

; sys_json_parse_number: Parses integer from buffer
; Input: RSI = buffer_ptr
; Output: RAX = integer value, RSI = buffer_ptr (after number)
sys_json_parse_number:
    push rbx
    push rcx
    push rdx

    xor rax, rax ; Result
    xor rbx, rbx ; Temp digit

    ; TODO: Handle negative sign?
    ; Added negative handling
    push r8
    mov r8, 1 ; sign multiplier (1 or -1)

    cmp byte [rsi], '-'
    jne .num_loop

    mov r8, -1
    inc rsi

.num_loop:
    mov cl, [rsi]
    cmp cl, '0'
    jl .done_num
    cmp cl, '9'
    jg .done_num

    sub cl, '0'
    movzx rbx, cl

    imul rax, 10
    add rax, rbx

    inc rsi
    jmp .num_loop

.done_num:
    imul rax, r8 ; Apply sign
    pop r8

    pop rdx
    pop rcx
    pop rbx
    ret
EOF
}

# --- Variable Handling ---

emit_variable_decl() {
    local name="$1"
    BSS_VARS+=("$name")
}

emit_variable_assign() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" ]]; then
        echo "    mov [var_$name], rax"
    elif [[ "$value" =~ ^-?[0-9]+$ ]]; then
        echo "    mov qword [var_$name], $value"
    elif [[ "$value" =~ ^\" ]]; then
        # String Literal Assignment to Var
        local content="${value%\"}"
        content="${content#\"}"
        local label="str_lit_$STR_COUNT"
        ((STR_COUNT++))

        cat <<EOF
section .data
    $label db \`$content\`, 0
section .text
    mov rax, $label
    mov [var_$name], rax
EOF
    else
        echo "    mov rax, [var_$value]"
        echo "    mov [var_$name], rax"
    fi
}

load_operand_to_rax() {
    local op="$1"
    if [[ "$op" =~ ^-?[0-9]+$ ]]; then
        echo "    mov rax, $op"
    elif [[ "$op" =~ ^\" ]]; then
        # String Literal as Operand
        local content="${op%\"}"
        content="${content#\"}"
        local label="str_lit_$STR_COUNT"
        ((STR_COUNT++))

        cat <<EOF
section .data
    $label db \`$content\`, 0
section .text
    mov rax, $label
EOF
    elif [[ -n "$op" ]]; then
        echo "    mov rax, [var_$op]"
    else
        echo "    xor rax, rax"
    fi
}

emit_arithmetic_op() {
    local op1="$1"
    local op="$2"
    local op2="$3"
    local store_to="$4"

    load_operand_to_rax "$op1"

    if [[ "$op2" =~ ^-?[0-9]+$ ]]; then
        echo "    mov rbx, $op2"
    else
        echo "    mov rbx, [var_$op2]"
    fi

    case "$op" in
        "+") echo "    add rax, rbx" ;;
        "-") echo "    sub rax, rbx" ;;
        "*") echo "    imul rax, rbx" ;;
        "/")
             echo "    cqo"          ; Sign extend RAX to RDX:RAX
             echo "    idiv rbx"
             ;;
    esac

    if [[ -n "$store_to" ]]; then
        echo "    mov [var_$store_to], rax"
    else
        # Implicit print result
        echo "    call print_int"
        echo "    call print_newline"
    fi
}

# --- Function & Flow Control ---

emit_function_start() {
    local name="$1"
    echo "$name:"
}

emit_function_end() {
    echo "    ret"
}

emit_print_str() {
    local content="$1"

    # Assume content is a variable name holding a pointer
    # Load pointer to RSI
    if [[ "$content" =~ ^[0-9]+$ ]]; then
        echo "    mov rsi, $content"
    else
        echo "    mov rsi, [var_$content]"
    fi
    echo "    call print_string_ptr"
}

emit_print() {
    local content="$1"

    if [[ "$content" =~ ^\" ]]; then
        # String Literal
        content="${content%\"}"
        content="${content#\"}"

        local label="msg_$STR_COUNT"
        ((STR_COUNT++))

        cat <<EOF
section .data
    $label db \`$content\`, 0
    len_$label equ $ - $label
section .text
    mov rsi, $label
    mov rdx, len_$label
    call print_string
    call print_newline
EOF

    elif [[ "$content" =~ ^[0-9]+$ ]]; then
        # Immediate Integer
        echo "    mov rax, $content"
        echo "    call print_int"
        echo "    call print_newline"

    elif [[ -n "$content" ]]; then
        # Variable
        echo "    mov rax, [var_$content]"
        echo "    call print_int"
        echo "    call print_newline"
    else
        # Implicit print (RAX)
        echo "    call print_int"
        echo "    call print_newline"
    fi
}

# --- Control Flow: IF / ELSE / ELSE IF ---

emit_if_start() {
    local op1="$1"
    local cond="$2"
    local op2="$3"

    local lbl_next_check="next_check_$LBL_COUNT"
    local lbl_end="end_$LBL_COUNT"
    ((LBL_COUNT++))

    IF_STACK+=("$lbl_end")
    IF_CHECK_STACK+=("$lbl_next_check")

    load_operand_to_rax "$op1"

    if [[ "$op2" =~ ^-?[0-9]+$ ]]; then
        echo "    mov rbx, $op2"
    else
        echo "    mov rbx, [var_$op2]"
    fi

    echo "    cmp rax, rbx"

    # Jump to Next Check if condition is FALSE
    case "$cond" in
        "==") echo "    jne $lbl_next_check" ;;
        "!=") echo "    je $lbl_next_check" ;;
        "<")  echo "    jge $lbl_next_check" ;;
        ">")  echo "    jle $lbl_next_check" ;;
        "<=") echo "    jg $lbl_next_check" ;;
        ">=") echo "    jl $lbl_next_check" ;;
    esac
}

emit_else_if() {
    local op1="$1"
    local cond="$2"
    local op2="$3"

    # 1. End previous block: Jump to END
    local lbl_end="${IF_STACK[-1]}"
    echo "    jmp $lbl_end"

    # 2. Define label for previous check failure
    local lbl_current_check="${IF_CHECK_STACK[-1]}"
    unset 'IF_CHECK_STACK[${#IF_CHECK_STACK[@]}-1]'
    echo "$lbl_current_check:"

    # 3. Start new check
    local lbl_next_check="next_check_$LBL_COUNT"
    ((LBL_COUNT++))
    IF_CHECK_STACK+=("$lbl_next_check")

    load_operand_to_rax "$op1"

    if [[ "$op2" =~ ^-?[0-9]+$ ]]; then
        echo "    mov rbx, $op2"
    else
        echo "    mov rbx, [var_$op2]"
    fi

    echo "    cmp rax, rbx"

    # Jump to Next Check if condition is FALSE
    case "$cond" in
        "==") echo "    jne $lbl_next_check" ;;
        "!=") echo "    je $lbl_next_check" ;;
        "<")  echo "    jge $lbl_next_check" ;;
        ">")  echo "    jle $lbl_next_check" ;;
        "<=") echo "    jg $lbl_next_check" ;;
        ">=") echo "    jl $lbl_next_check" ;;
    esac
}

emit_else() {
    # 1. End previous block: Jump to END
    local lbl_end="${IF_STACK[-1]}"
    echo "    jmp $lbl_end"

    # 2. Define label for previous check failure
    local lbl_current_check="${IF_CHECK_STACK[-1]}"
    unset 'IF_CHECK_STACK[${#IF_CHECK_STACK[@]}-1]'
    echo "$lbl_current_check:"

    # 3. Push empty marker to stack so size matches IF_STACK
    # (Or just don't push anything, IF_CHECK_STACK size < IF_STACK size)
    # We will choose NOT to push anything, and check for empty on emit_if_end.
}

emit_if_end() {
    local lbl_end="${IF_STACK[-1]}"
    unset 'IF_STACK[${#IF_STACK[@]}-1]'

    # If there is a pending check label (i.e. we did NOT hit 'else'), define it
    # This handles the "Fallthrough" case where no condition met and no else exists.
    if [ ${#IF_CHECK_STACK[@]} -gt ${#IF_STACK[@]} ]; then
        local lbl_fallthrough="${IF_CHECK_STACK[-1]}"
        unset 'IF_CHECK_STACK[${#IF_CHECK_STACK[@]}-1]'
        echo "$lbl_fallthrough:"
    fi

    echo "$lbl_end:"
}

emit_loop_start() {
    local op1="$1"
    local cond="$2"
    local op2="$3"

    local lbl_start="loop_start_$LBL_COUNT"
    local lbl_end="loop_end_$LBL_COUNT"
    ((LBL_COUNT++))

    LOOP_STACK_START+=("$lbl_start")
    LOOP_STACK_END+=("$lbl_end")

    echo "$lbl_start:"
    load_operand_to_rax "$op1"
    if [[ "$op2" =~ ^-?[0-9]+$ ]]; then
        echo "    mov rbx, $op2"
    else
        echo "    mov rbx, [var_$op2]"
    fi
    echo "    cmp rax, rbx"
    case "$cond" in
        "==") echo "    jne $lbl_end" ;;
        "!=") echo "    je $lbl_end" ;;
        "<")  echo "    jge $lbl_end" ;;
        ">")  echo "    jle $lbl_end" ;;
        "<=") echo "    jg $lbl_end" ;;
        ">=") echo "    jl $lbl_end" ;;
    esac
}

emit_loop_end() {
    local lbl_start="${LOOP_STACK_START[-1]}"
    local lbl_end="${LOOP_STACK_END[-1]}"
    unset 'LOOP_STACK_START[${#LOOP_STACK_START[@]}-1]'
    unset 'LOOP_STACK_END[${#LOOP_STACK_END[@]}-1]'
    echo "    jmp $lbl_start"
    echo "$lbl_end:"
}

emit_call() {
    local name="$1"
    echo "    call $name"
}

emit_read() {
    local size="$1"
    if [[ "$size" =~ ^[0-9]+$ ]]; then
        echo "    mov rax, $size"
    else
        echo "    mov rax, [var_$size]"
    fi
    echo "    call sys_read"
}

emit_struct_alloc_and_init() {
    local size="$1"
    local offsets=($2) # Space separated offsets
    local values=($3)  # Space separated values

    # 1. Allocate Struct
    echo "    mov rax, $size"
    echo "    call sys_alloc"
    echo "    push rax"        # ; Save struct ptr

    # 2. Init Fields
    # Iterate both arrays
    local count=${#offsets[@]}
    for (( i=0; i<count; i++ )); do
        local off=${offsets[$i]}
        local val=${values[$i]}

        # Load value (support immediate or variable)
        if [[ "$val" =~ ^-?[0-9]+$ ]]; then
            echo "    mov rbx, $val"
        else
            echo "    mov rbx, [var_$val]"
        fi

        # Store to [struct_ptr + offset]
        echo "    mov rdx, [rsp]"  # ; Peek struct ptr
        echo "    mov [rdx + $off], rbx"
    done

    # 3. Return ptr
    echo "    pop rax"
}

emit_load_struct_field() {
    local var_name="$1"
    local offset="$2"

    # Load struct pointer
    echo "    mov rbx, [var_$var_name]"
    # Load field value
    echo "    mov rax, [rbx + $offset]"
}

emit_store_struct_field() {
    local var_name="$1"
    local offset="$2"
    local value="$3"

    # Load struct pointer
    echo "    mov rdx, [var_$var_name]"

    # Load value
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        echo "    mov rax, $value"
    else
        echo "    mov rax, [var_$value]"
    fi

    # Store
    echo "    mov [rdx + $offset], rax"
}

emit_str_concat() {
    local op1="$1"
    local op2="$2"

    # Load op1 to RSI
    if [[ "$op1" =~ ^\" ]]; then
        # Literal string (Not implemented efficiently yet, need label)
        # Assuming only variables for now in str_concat
        :
    else
        echo "    mov rsi, [var_$op1]"
    fi

    # Load op2 to RDX
    if [[ "$op2" =~ ^\" ]]; then
        :
    else
        echo "    mov rdx, [var_$op2]"
    fi

    echo "    call sys_str_concat"
}

emit_str_eq() {
    local op1="$1"
    local op2="$2"

    # Load op1 to RSI
    if [[ "$op1" =~ ^\" ]]; then
        # Handle string literal? For now assume variables.
        # Ideally we should generate label if it's literal.
        :
    else
        echo "    mov rsi, [var_$op1]"
    fi

    # Load op2 to RDX
    if [[ "$op2" =~ ^\" ]]; then
        :
    else
        echo "    mov rdx, [var_$op2]"
    fi

    echo "    call sys_strcmp"
}

emit_str_get() {
    local str_var="$1"
    local index="$2"

    # Load string pointer to RSI
    echo "    mov rsi, [var_$str_var]"

    # Load index to RBX
    if [[ "$index" =~ ^[0-9]+$ ]]; then
        echo "    mov rbx, $index"
    else
        echo "    mov rbx, [var_$index]"
    fi

    # Load byte at [rsi + rbx] into AL, then zero extend to RAX
    echo "    movzx rax, byte [rsi + rbx]"
}

emit_array_alloc() {
    local size="$1"
    # size is number of elements
    # total bytes = size * 8

    echo "    mov rax, $size"
    echo "    mov rbx, 8"
    echo "    mul rbx"        # ; rax = size * 8
    echo "    call sys_alloc"
    # Result in RAX (pointer)
}

emit_load_array_elem() {
    local arr_var="$1"
    local index="$2"

    # Load base pointer
    echo "    mov rbx, [var_$arr_var]"

    # Load index
    if [[ "$index" =~ ^[0-9]+$ ]]; then
        echo "    mov rcx, $index"
    else
        echo "    mov rcx, [var_$index]"
    fi

    # address = rbx + (rcx * 8)
    echo "    mov rax, [rbx + rcx * 8]"
}

emit_store_array_elem() {
    local arr_var="$1"
    local index="$2"
    local value="$3"

    # Load base pointer
    echo "    mov rbx, [var_$arr_var]"

    # Load index
    if [[ "$index" =~ ^[0-9]+$ ]]; then
        echo "    mov rcx, $index"
    else
        echo "    mov rcx, [var_$index]"
    fi

    # Load value
    if [[ "$value" =~ ^\" ]]; then
        # String Literal!
        local content="${value%\"}"
        content="${content#\"}"
        local label="str_lit_$STR_COUNT"
        ((STR_COUNT++))

        cat <<EOF
section .data
    $label db \`$content\`, 0
section .text
    mov rax, $label
EOF
    elif [[ "$value" =~ ^-?[0-9]+$ ]]; then
        echo "    mov rax, $value"
    else
        echo "    mov rax, [var_$value]"
    fi

    # Store
    echo "    mov [rbx + rcx * 8], rax"
}

emit_string_literal_assign() {
    local name="$1"
    local content="$2"

    local label="str_lit_$STR_COUNT"
    ((STR_COUNT++))

    # Define string in data
    cat <<EOF
section .data
    $label db \`$content\`, 0
section .text
    mov rax, $label
    mov [var_$name], rax
EOF
}

emit_snapshot() {
    echo "    push rax"
    echo "    push rbx"
    echo "    push rcx"
    echo "    push rdx"
    echo "    push rsi"
    echo "    push rdi"
}

emit_restore() {
    echo "    pop rdi"
    echo "    pop rsi"
    echo "    pop rdx"
    echo "    pop rcx"
    echo "    pop rbx"
    echo "    pop rax"
}

emit_raw_asm() {
    local asm_line="$1"
    echo "    $asm_line"
}
emit_raw_data_fixed() {
    local data_line="$1"
    echo "section .data"
    echo "    $data_line"
    echo "section .text"
}

emit_output() {
    # BSS Injection with Deduplication:
    echo "section .bss"
    # REMOVED: heap_space resb ...

    # Heap State Pointers (8 bytes each)
    echo "    heap_start_ptr   resq 1"
    echo "    heap_current_ptr resq 1"
    echo "    heap_end_ptr     resq 1"

    # Global Args (Always define them so _start doesn't fail)
    echo "    var_global_argc  resq 1"
    echo "    var_global_argv  resq 1"

    if [ ${#BSS_VARS[@]} -gt 0 ]; then
        # Deduplicate using sort -u
        local unique_vars=($(printf "%s\n" "${BSS_VARS[@]}" | sort -u))
        for var in "${unique_vars[@]}"; do
            echo "    var_$var resq 1"
        done
    fi

    # Exit
    echo "section .text"
    echo "    mov rax, 60"
    echo "    xor rdi, rdi"
    echo "    syscall"
}
