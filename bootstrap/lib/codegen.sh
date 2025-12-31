# Codegen: Generates NASM Assembly for Linux x86-64

# Global State
STR_COUNT=0
LBL_COUNT=0
declare -a BSS_VARS

init_codegen() {
    cat <<EOF
section .data
    newline db 10, 0

section .text
    global _start

_start:
    ; Initialize stack frame if needed
    mov rbp, rsp

    ; Call entry point
    call mulai

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

; --- Helper Functions ---

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

; sys_alloc: Allocates N bytes from heap
; Input: RAX = size
; Output: RAX = pointer
sys_alloc:
    push rbx
    push rdx

    ; Align size to 8 bytes (simple bump)
    ; TODO: Better alignment

    mov rbx, [heap_ptr]     ; Current offset
    lea rdx, [heap_space + rbx] ; Calculate absolute address

    add rbx, rax            ; Bump pointer
    mov [heap_ptr], rbx     ; Save new offset

    mov rax, rdx            ; Return pointer

    pop rdx
    pop rbx
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

; sys_read: Reads N bytes from stdin to new heap buffer
; Input: RAX = max_size
; Output: RAX = buffer_pointer
sys_read:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; 1. Allocate buffer
    mov rbx, rax    ; rbx = size
    call sys_alloc  ; rax = buffer_pointer

    ; 2. Syscall Read
    mov rsi, rax    ; buf
    mov rdx, rbx    ; count
    mov rax, 0      ; sys_read
    mov rdi, 0      ; stdin
    syscall

    ; Null-terminate the input for safety
    mov byte [rsi + rax], 0

    ; We return the buffer pointer (which is in RSI)
    mov rax, rsi

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
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
    else
        echo "    mov rax, [var_$value]"
        echo "    mov [var_$name], rax"
    fi
}

load_operand_to_rax() {
    local op="$1"
    if [[ "$op" =~ ^[0-9]+$ ]]; then
        echo "    mov rax, $op"
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

    if [[ "$op2" =~ ^[0-9]+$ ]]; then
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
    $label db "$content", 0
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

emit_if_start() {
    local op1="$1"
    local cond="$2"
    local op2="$3"

    local lbl_else="else_$LBL_COUNT"
    local lbl_end="end_$LBL_COUNT"
    ((LBL_COUNT++))

    IF_STACK+=("$lbl_end")

    load_operand_to_rax "$op1"

    if [[ "$op2" =~ ^[0-9]+$ ]]; then
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

emit_if_end() {
    local lbl_end="${IF_STACK[-1]}"
    unset 'IF_STACK[${#IF_STACK[@]}-1]'
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
    if [[ "$op2" =~ ^[0-9]+$ ]]; then
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
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
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
    $label db "$content", 0
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
    # BSS Injection:
    echo "section .bss"
    echo "    heap_space resb 1048576 ; 1MB Arena"
    echo "    heap_ptr resq 1"

    if [ ${#BSS_VARS[@]} -gt 0 ]; then
        for var in "${BSS_VARS[@]}"; do
            echo "    var_$var resq 1"
        done
    fi

    # Exit
    echo "section .text"
    echo "    mov rax, 60"
    echo "    xor rdi, rdi"
    echo "    syscall"
}
