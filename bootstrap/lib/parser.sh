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
                # Entry point handle implicitly by _start in codegen init
                ;;
            "akhir")
                emit_exit
                ;;
            cetak*)
                if [[ "$line" =~ ^cetak\(\"(.*)\"\)$ ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print "$content"
                fi
                ;;
            *)
                # Ignore unknown or comments for now
                ;;
        esac
    done < "$input_file"

    emit_output
}
