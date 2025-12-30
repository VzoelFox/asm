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
    # Kita tambahkan di bagian akhir text section nanti atau define sekarang
    # Untuk simplisitas, kita append logic ini di akhir file output atau simpan di variable
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

# Fungsi untuk generate sys_write (String)
emit_print() {
    local content="$1"
    emit_string "$content"

    TEXT_SECTION="$TEXT_SECTION
    ; cetak string $LAST_LABEL
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, $LAST_LABEL     ; buffer
    mov rdx, $LAST_LEN_LABEL ; length
    syscall"
}

# Fungsi untuk generate operasi aritmatika dan print hasilnya
# Usage: emit_arithmetic_op "num1" "op" "num2"
emit_arithmetic_op() {
    local num1="$1"
    local op="$2"
    local num2="$3"

    local asm_op="add"
    if [ "$op" == "-" ]; then
        asm_op="sub"
    elif [ "$op" == "*" ]; then
        asm_op="imul"
    fi

    TEXT_SECTION="$TEXT_SECTION
    ; Hitung $num1 $op $num2
    mov rax, $num1
    $asm_op rax, $num2
    call _print_int"
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
