# Fungsi untuk emit assembly code

# Inisialisasi variabel global untuk codegen
init_codegen() {
    DATA_SECTION="section .data"
    BSS_SECTION="section .bss
    int_buffer resb 20"

    # Separate buffers for functions and main entry logic
    TEXT_FUNCTIONS=""
    TEXT_MAIN=""

    # Global flag to determine where to write code
    # 0 = Main (_start), 1 = Functions
    WRITE_TO_FUNCTIONS=0

    # Helper Functions Assembly
    HELPER_FUNCTIONS="
_print_int:
    ; Input: rax = integer to print
    ; Output: print to stdout with newline

    mov rcx, int_buffer + 19 ; Point to end of buffer
    mov byte [rcx], 10       ; Newline
    dec rcx

    mov rbx, 10              ; Divisor

    cmp rax, 0
    jne .convert_loop
    mov byte [rcx], '0'
    dec rcx
    jmp .print_done

.convert_loop:
    xor rdx, rdx
    div rbx                  ; rax / 10, rdx = remainder
    add dl, '0'              ; Convert to ASCII
    mov [rcx], dl
    dec rcx
    test rax, rax
    jnz .convert_loop

.print_done:
    inc rcx                  ; Point to start of string

    ; Calculate length
    mov rdx, int_buffer + 20
    sub rdx, rcx             ; Length = End - Start

    ; sys_write
    mov rax, 1
    mov rdi, 1
    mov rsi, rcx
    syscall
    ret"

    STR_COUNT=0
    IF_COUNT=0
    IF_STACK=""
    LOOP_COUNT=0
    LOOP_STACK=""
}

# Helper to append code to correct buffer
emit_code() {
    local code="$1"
    if [ "$WRITE_TO_FUNCTIONS" -eq 1 ]; then
        TEXT_FUNCTIONS="$TEXT_FUNCTIONS
$code"
    else
        TEXT_MAIN="$TEXT_MAIN
$code"
    fi
}

emit_string() {
    local content="$1"
    local label="msg_$STR_COUNT"
    local len_label="len_$STR_COUNT"

    DATA_SECTION="$DATA_SECTION
    $label db \"$content\", 10
    $len_label equ $ - $label"

    LAST_LABEL="$label"
    LAST_LEN_LABEL="$len_label"
    ((STR_COUNT++))
}

emit_variable_decl() {
    local name="$1"
    BSS_SECTION="$BSS_SECTION
    var_$name resq 1"
}

emit_variable_assign() {
    local name="$1"
    local value="$2"
    if [ -n "$value" ]; then
        emit_code "    ; Assign $value to $name
    mov qword [var_$name], $value"
    else
        emit_code "    ; Assign rax to $name
    mov qword [var_$name], rax"
    fi
}

load_operand_to_rax() {
    local op="$1"
    if [[ "$op" =~ ^[0-9]+$ ]]; then
        emit_code "    mov rax, $op"
    else
        emit_code "    mov rax, [var_$op]"
    fi
}

load_operand_to_rbx() {
    local op="$1"
    if [[ "$op" =~ ^[0-9]+$ ]]; then
        emit_code "    mov rbx, $op"
    else
        emit_code "    mov rbx, [var_$op]"
    fi
}

emit_print() {
    local content="$1"
    if [[ "$content" =~ ^\" ]]; then
        content="${content%\"}"
        content="${content#\"}"
        emit_string "$content"
        emit_code "    ; cetak string $LAST_LABEL
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, $LAST_LABEL     ; buffer
    mov rdx, $LAST_LEN_LABEL ; length
    syscall"
    elif [[ "$content" =~ ^[0-9]+$ ]]; then
         emit_code "    mov rax, $content
    call _print_int"
    else
         emit_code "    mov rax, [var_$content]
    call _print_int"
    fi
}

emit_arithmetic_op() {
    local num1="$1"
    local op="$2"
    local num2="$3"
    local store_to="$4"

    load_operand_to_rax "$num1"
    load_operand_to_rbx "$num2"

    local asm_op="add"
    if [ "$op" == "-" ]; then asm_op="sub"; elif [ "$op" == "*" ]; then asm_op="imul"; fi

    emit_code "    ; Hitung $num1 $op $num2
    $asm_op rax, rbx"

    if [ -n "$store_to" ]; then
        emit_variable_assign "$store_to" ""
    else
        emit_code "    call _print_int"
    fi
}

# --- PERCABANGAN ---
push_if_stack() { IF_STACK="$1 $IF_STACK"; }
pop_if_stack() { POPPED_VAL=${IF_STACK%% *}; IF_STACK=${IF_STACK#* }; }

emit_if_start() {
    local op1="$1"; local cond="$2"; local op2="$3"; local label_id=$IF_COUNT
    load_operand_to_rax "$op1"
    load_operand_to_rbx "$op2"
    emit_code "    cmp rax, rbx"
    local jump_instr="jmp"
    case "$cond" in
        "==") jump_instr="jne" ;; "!=") jump_instr="je"  ;;
        ">")  jump_instr="jle" ;; "<")  jump_instr="jge" ;;
        ">=") jump_instr="jl"  ;; "<=") jump_instr="jg"  ;;
    esac
    emit_code "    $jump_instr .Lend_if_$label_id"
    push_if_stack "$label_id"
    ((IF_COUNT++))
}

emit_if_end() {
    pop_if_stack
    emit_code ".Lend_if_$POPPED_VAL:"
}

# --- LOOP ---
push_loop_stack() { LOOP_STACK="$1 $LOOP_STACK"; }
pop_loop_stack() { POPPED_LOOP_VAL=${LOOP_STACK%% *}; LOOP_STACK=${LOOP_STACK#* }; }

emit_loop_start() {
    local op1="$1"; local cond="$2"; local op2="$3"; local label_id=$LOOP_COUNT
    emit_code ".Lloop_start_$label_id:"
    load_operand_to_rax "$op1"
    load_operand_to_rbx "$op2"
    emit_code "    cmp rax, rbx"
    local jump_instr="jmp"
    case "$cond" in
        "==") jump_instr="jne" ;; "!=") jump_instr="je"  ;;
        ">")  jump_instr="jle" ;; "<")  jump_instr="jge" ;;
        ">=") jump_instr="jl"  ;; "<=") jump_instr="jg"  ;;
    esac
    emit_code "    $jump_instr .Lloop_end_$label_id"
    push_loop_stack "$label_id"
    ((LOOP_COUNT++))
}

emit_loop_end() {
    pop_loop_stack
    emit_code "    jmp .Lloop_start_$POPPED_LOOP_VAL
.Lloop_end_$POPPED_LOOP_VAL:"
}

# --- FUNCTIONS ---
ARG_REGS=("rdi" "rsi" "rdx" "rcx" "r8" "r9")

emit_function_start() {
    local name="$1"
    local args_list="$2"

    if [ "$name" == "mulai" ]; then
        WRITE_TO_FUNCTIONS=0
        # Main entry doesn't need label in logic buffer, handled in emit_output
        return
    else
        WRITE_TO_FUNCTIONS=1
        emit_code "$name:
    push rbp
    mov rbp, rsp"

        IFS=',' read -ra ADDR <<< "$args_list"
        local i=0
        for arg in "${ADDR[@]}"; do
            arg=$(echo "$arg" | xargs)
            if [ -n "$arg" ]; then
                emit_variable_decl "$arg"
                local reg="${ARG_REGS[$i]}"
                emit_code "    mov qword [var_$arg], $reg"
                ((i++))
            fi
        done
    fi
}

emit_function_end() {
    local name="$1"
    if [ "$name" == "mulai" ]; then
        emit_exit
    else
        emit_code "    mov rsp, rbp
    pop rbp
    ret"
    fi
}

emit_call() {
    local name="$1"
    local args_list="$2"
    IFS=',' read -ra ADDR <<< "$args_list"
    local i=0
    for arg in "${ADDR[@]}"; do
        arg=$(echo "$arg" | xargs)
        local reg="${ARG_REGS[$i]}"
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            emit_code "    mov $reg, $arg"
        else
            emit_code "    mov $reg, [var_$arg]"
        fi
        ((i++))
    done
    emit_code "    call $name"
}

emit_snapshot() {
    emit_code "    ; Snapshot
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11"
}

emit_restore() {
    emit_code "    ; Restore
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax"
}

emit_raw_asm() { emit_code "$1"; }
emit_raw_data() { emit_code "$1"; } # Wait, raw data should go to DATA_SECTION always?
# Fix: raw data usually goes to .data, but parser calls emit_raw_data for 'asm_data' block
# So let's redirect to DATA_SECTION
emit_raw_data_fixed() {
    DATA_SECTION="$DATA_SECTION
    $1"
}

emit_exit() {
    emit_code "    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall"
}

emit_output() {
    echo "$DATA_SECTION"
    echo ""
    echo "$BSS_SECTION"
    echo ""
    echo "section .text
    global _start"

    echo "$TEXT_FUNCTIONS"

    echo "_start:
$TEXT_MAIN"

    echo "$HELPER_FUNCTIONS"
}
