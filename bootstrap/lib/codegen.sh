# Fungsi untuk emit assembly code

# Inisialisasi variabel global untuk codegen
init_codegen() {
    DATA_SECTION="section .data"
    TEXT_SECTION="section .text
    global _start

_start:"
    STR_COUNT=0
}

# Fungsi untuk menambahkan string ke .data section
# Usage: emit_string "content"
emit_string() {
    local content="$1"
    local label="msg_$STR_COUNT"
    local len_label="len_$STR_COUNT"

    # Append to DATA_SECTION
    # Note: Using printf to handle newlines correctly if needed, but for now string concat is fine
    DATA_SECTION="$DATA_SECTION
    $label db \"$content\", 10
    $len_label equ $ - $label"

    # Return labels via global vars or echo?
    # Let's use global vars for simplicity in this shell scope
    LAST_LABEL="$label"
    LAST_LEN_LABEL="$len_label"

    ((STR_COUNT++))
}

# Fungsi untuk generate sys_write
# Usage: emit_print "content"
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
    echo "$TEXT_SECTION"
}
