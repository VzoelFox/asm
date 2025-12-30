# Fungsi parsing

# Note: codegen.sh should be sourced by the main script before this.

parse_file() {
    local input_file="$1"

    init_codegen

    while IFS= read -r line || [ -n "$line" ]; do
        # Trim whitespace
        line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')

        # Skip empty
        if [ -z "$line" ]; then continue; fi

        # Parsing Logic
        case "$line" in
            "fungsi mulai()")
                ;;
            "akhir")
                emit_exit
                ;;
            cetak*)
                # Cek apakah string: cetak("...")
                if [[ "$line" =~ ^cetak\(\"(.*)\"\)$ ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print "$content"

                # Cek apakah ekspresi aritmatika: cetak(1 + 2)
                # Regex menangkap: angka spasi operator spasi angka
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
