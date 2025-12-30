#!/bin/bash

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
    echo "Penggunaan: $0 <file.fox>"
    exit 1
fi

# Variabel untuk menampung bagian .data dan .text
DATA_SECTION="section .data"
TEXT_SECTION="section .text
    global _start

_start:"

# Counter untuk label string
STR_COUNT=0

# Membaca file baris per baris
while IFS= read -r line || [ -n "$line" ]; do
    # Hapus whitespace di awal dan akhir
    line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')

    # Skip baris kosong
    if [ -z "$line" ]; then
        continue
    fi

    # Parsing 'fungsi mulai()' -> entry point sudah dihandle oleh global _start
    if [[ "$line" == "fungsi mulai()" ]]; then
        continue
    fi

    # Parsing 'akhir' -> sys_exit
    if [[ "$line" == "akhir" ]]; then
        TEXT_SECTION="$TEXT_SECTION
    ; Exit program
    mov rax, 60
    xor rdi, rdi
    syscall"
        continue
    fi

    # Parsing 'cetak("...")'
    if [[ "$line" =~ ^cetak\(\"(.*)\"\)$ ]]; then
        CONTENT="${BASH_REMATCH[1]}"
        LABEL="msg_$STR_COUNT"
        LEN_LABEL="len_$STR_COUNT"

        # Tambahkan ke .data
        # Note: db string, 10 (newline)
        DATA_SECTION="$DATA_SECTION
    $LABEL db \"$CONTENT\", 10
    $LEN_LABEL equ $ - $LABEL"

        # Tambahkan ke .text
        TEXT_SECTION="$TEXT_SECTION
    ; cetak string $LABEL
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, $LABEL     ; buffer
    mov rdx, $LEN_LABEL ; length
    syscall"

        ((STR_COUNT++))
    fi

done < "$INPUT_FILE"

# Gabungkan dan output
echo "$DATA_SECTION"
echo ""
echo "$TEXT_SECTION"
