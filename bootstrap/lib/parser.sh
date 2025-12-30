# Fungsi parsing

# Note: codegen.sh should be sourced by the main script before this.

parse_file() {
    local input_file="$1"

    init_codegen

    local in_asm_block=0
    local in_data_block=0

    while IFS= read -r line || [ -n "$line" ]; do
        # Trim whitespace
        line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')

        # Skip empty
        if [ -z "$line" ]; then continue; fi

        # --- Handle Blocks (ASM & Data) ---
        if [ "$in_asm_block" -eq 1 ]; then
            if [ "$line" == "tutup_asm" ]; then
                in_asm_block=0
            else
                emit_raw_asm "$line"
            fi
            continue
        fi

        if [ "$in_data_block" -eq 1 ]; then
            if [ "$line" == "tutup_data" ]; then
                in_data_block=0
            else
                emit_raw_data "$line"
            fi
            continue
        fi

        # --- Handle Normal Statements ---
        case "$line" in
            "fungsi mulai()")
                ;;
            "tutup_fungsi")
                emit_exit
                ;;
            "asm_mulai")
                in_asm_block=1
                ;;
            "asm_data")
                in_data_block=1
                ;;
            cetak*)
                # Cek apakah string: cetak("...")
                if [[ "$line" =~ ^cetak\(\"(.*)\"\)$ ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print "$content"

                # Cek apakah ekspresi aritmatika: cetak(1 + 2)
                elif [[ "$line" =~ ^cetak\(([0-9]+)[[:space:]]*([-+*])[[:space:]]*([0-9]+)\)$ ]]; then
                    local num1="${BASH_REMATCH[1]}"
                    local op="${BASH_REMATCH[2]}"
                    local num2="${BASH_REMATCH[3]}"
                    emit_arithmetic_op "$num1" "$op" "$num2"
                fi
                ;;
            *)
                # Ignore unknown
                ;;
        esac
    done < "$input_file"

    emit_output
}
