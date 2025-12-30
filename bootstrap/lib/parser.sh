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

            # --- Variabel ---
            # var x = 10
            # var x = 10 + y
            var*)
                if [[ "$line" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local expr="${BASH_REMATCH[2]}"

                    emit_variable_decl "$name"

                    # Cek apakah expr adalah aritmatika: op1 + op2
                    if [[ "$expr" =~ ^([a-zA-Z0-9_]+)[[:space:]]*([-+*])[[:space:]]*([a-zA-Z0-9_]+)$ ]]; then
                         local op1="${BASH_REMATCH[1]}"
                         local op="${BASH_REMATCH[2]}"
                         local op2="${BASH_REMATCH[3]}"
                         emit_arithmetic_op "$op1" "$op" "$op2" "$name"
                    else
                        # Simple assignment: var x = 10 or var x = y
                        # Cek apakah itu referensi ke variabel lain (bukan angka murni)
                        if [[ ! "$expr" =~ ^[0-9]+$ ]]; then
                           # Emit assignment using helper to load from var
                           emit_variable_assign "$name" "" # Trigger load from rax logic? No wait.
                           # Manual logic for var to var assignment:
                           load_operand_to_rax "$expr"
                           emit_variable_assign "$name" "" # Assigns value in RAX to name
                        else
                           emit_variable_assign "$name" "$expr"
                        fi
                    fi
                fi
                ;;

            cetak*)
                # cetak("...") -> String
                if [[ "$line" =~ ^cetak\(\"(.*)\"\) ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print "\"$content\"" # Pass quotes to indicate string

                # cetak(expr) -> Aritmatika: cetak(x + y) or cetak(10 + x)
                elif [[ "$line" =~ ^cetak\(([a-zA-Z0-9_]+)[[:space:]]*([-+*])[[:space:]]*([a-zA-Z0-9_]+)\)$ ]]; then
                    local op1="${BASH_REMATCH[1]}"
                    local op="${BASH_REMATCH[2]}"
                    local op2="${BASH_REMATCH[3]}"
                    emit_arithmetic_op "$op1" "$op" "$op2"

                # cetak(var) or cetak(int)
                elif [[ "$line" =~ ^cetak\(([a-zA-Z0-9_]+)\)$ ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print "$content"
                fi
                ;;
            *)
                # Ignore unknown
                ;;
        esac
    done < "$input_file"

    emit_output
}
