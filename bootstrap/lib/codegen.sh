# Fungsi untuk emit assembly code

# Inisialisasi variabel global untuk codegen
init_codegen() {
    DATA_SECTION="section .data"
    BSS_SECTION="section .bss
    int_buffer resb 20"

    TEXT_SECTION="section .text
    global _start

_start:"

    # Fungsi helper untuk convert int (rax) to string dan print
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
}

# Fungsi untuk menambahkan string ke .data section
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

# Fungsi untuk declare variabel di .bss (integer 64-bit)
emit_variable_decl() {
    local name="$1"
    BSS_SECTION="$BSS_SECTION
    var_$name resq 1"
}

# Fungsi untuk assign value ke variabel
# Value bisa berupa angka literal atau hasil dari rax (jika kosong)
emit_variable_assign() {
    local name="$1"
    local value="$2"

    if [ -n "$value" ]; then
        TEXT_SECTION="$TEXT_SECTION
    ; Assign $value to $name
    mov qword [var_$name], $value"
    else
        # Jika value kosong, asumsikan nilai ada di rax (hasil komputasi sebelumnya)
        TEXT_SECTION="$TEXT_SECTION
    ; Assign rax to $name
    mov qword [var_$name], rax"
    fi
}

# Fungsi helper: load operand ke register rax
# Operand bisa angka literal atau nama variabel
load_operand_to_rax() {
    local op="$1"
    # Cek apakah angka (regex)
    if [[ "$op" =~ ^[0-9]+$ ]]; then
        TEXT_SECTION="$TEXT_SECTION
    mov rax, $op"
    else
        # Asumsikan variabel
        TEXT_SECTION="$TEXT_SECTION
    mov rax, [var_$op]"
    fi
}

# Helper: load operand kedua ke register (misal rbx) untuk operasi
load_operand_to_rbx() {
    local op="$1"
    if [[ "$op" =~ ^[0-9]+$ ]]; then
        TEXT_SECTION="$TEXT_SECTION
    mov rbx, $op"
    else
        TEXT_SECTION="$TEXT_SECTION
    mov rbx, [var_$op]"
    fi
}

# Fungsi untuk generate sys_write (String atau Var/Int)
emit_print() {
    local content="$1"

    # Cek apakah ini string literal (diawali ")
    if [[ "$content" =~ ^\" ]]; then
        # Hapus quote pembungkus
        content="${content%\"}"
        content="${content#\"}"
        emit_string "$content"
        TEXT_SECTION="$TEXT_SECTION
    ; cetak string $LAST_LABEL
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, $LAST_LABEL     ; buffer
    mov rdx, $LAST_LEN_LABEL ; length
    syscall"

    # Jika angka literal
    elif [[ "$content" =~ ^[0-9]+$ ]]; then
         TEXT_SECTION="$TEXT_SECTION
    mov rax, $content
    call _print_int"

    # Jika nama variabel
    else
         TEXT_SECTION="$TEXT_SECTION
    mov rax, [var_$content]
    call _print_int"
    fi
}


# Fungsi untuk generate operasi aritmatika dan print hasilnya
# Supports variable operands
emit_arithmetic_op() {
    local num1="$1"
    local op="$2"
    local num2="$3"
    local store_to="$4" # Optional: variabel untuk menyimpan hasil

    load_operand_to_rax "$num1"
    load_operand_to_rbx "$num2"

    local asm_op="add"
    if [ "$op" == "-" ]; then
        asm_op="sub"
    elif [ "$op" == "*" ]; then
        asm_op="imul"
    fi

    TEXT_SECTION="$TEXT_SECTION
    ; Hitung $num1 $op $num2
    $asm_op rax, rbx"

    if [ -n "$store_to" ]; then
        emit_variable_assign "$store_to" "" # Empty value means use rax
    else
        TEXT_SECTION="$TEXT_SECTION
    call _print_int"
    fi
}

# Fungsi untuk emit raw assembly instructions (inline asm)
emit_raw_asm() {
    local line="$1"
    TEXT_SECTION="$TEXT_SECTION
    $line"
}

# Fungsi untuk emit raw data definitions
emit_raw_data() {
    local line="$1"
    DATA_SECTION="$DATA_SECTION
    $line"
}

# Fungsi untuk generate sys_exit
emit_exit() {
    TEXT_SECTION="$TEXT_SECTION
    ; Exit program
    mov rax, 60
    xor rdi, rdi
    syscall"
}

# Fungsi untuk mencetak output akhir
emit_output() {
    echo "$DATA_SECTION"
    echo ""
    echo "$BSS_SECTION"
    echo ""
    echo "$TEXT_SECTION"
    echo ""
    echo "$HELPER_FUNCTIONS"
}
