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

        # Track function name BEFORE processing line if it's a function declaration
        if [[ "$line" =~ ^fungsi[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\( ]]; then
            CURRENT_FUNC_NAME="${BASH_REMATCH[1]}"
        fi

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
                emit_raw_data_fixed "$line"
            fi
            continue
        fi

        # --- Handle Normal Statements ---
        case "$line" in
            # fungsi nama(arg1, arg2)
            fungsi*)
                if [[ "$line" =~ ^fungsi[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\((.*)\)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local args="${BASH_REMATCH[2]}"
                    emit_function_start "$name" "$args"
                fi
                ;;

            "tutup_fungsi")
                emit_function_end "$CURRENT_FUNC_NAME"
                ;;

            "simpan")
                emit_snapshot
                ;;

            "kembalikan")
                emit_restore
                ;;

            "asm_mulai")
                in_asm_block=1
                ;;
            "asm_data")
                in_data_block=1
                ;;

            # --- Call (panggil) ---
            panggil*)
                if [[ "$line" =~ ^panggil[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\((.*)\)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local args="${BASH_REMATCH[2]}"
                    emit_call "$name" "$args"
                fi
                ;;

            # --- Variabel (Deklarasi) ---
            var*)
                if [[ "$line" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local expr="${BASH_REMATCH[2]}"

                    emit_variable_decl "$name"

                    if [[ "$expr" =~ ^([a-zA-Z0-9_]+)[[:space:]]*([-+*])[[:space:]]*([a-zA-Z0-9_]+)$ ]]; then
                         local op1="${BASH_REMATCH[1]}"
                         local op="${BASH_REMATCH[2]}"
                         local op2="${BASH_REMATCH[3]}"
                         emit_arithmetic_op "$op1" "$op" "$op2" "$name"
                    else
                        if [[ ! "$expr" =~ ^[0-9]+$ ]]; then
                           load_operand_to_rax "$expr"
                           emit_variable_assign "$name" ""
                        else
                           emit_variable_assign "$name" "$expr"
                        fi
                    fi
                fi
                ;;

            # --- Percabangan ---
            jika*)
                if [[ "$line" =~ ^jika[[:space:]]*\((.*)[[:space:]]*(==|!=|>=|<=|>|<)[[:space:]]*(.*)\)$ ]]; then
                    local op1="${BASH_REMATCH[1]}"
                    local cond="${BASH_REMATCH[2]}"
                    local op2="${BASH_REMATCH[3]}"
                    op1=$(echo "$op1" | xargs)
                    op2=$(echo "$op2" | xargs)
                    emit_if_start "$op1" "$cond" "$op2"
                fi
                ;;

            "tutup_jika")
                emit_if_end
                ;;

            # --- Loop (Selama) ---
            selama*)
                if [[ "$line" =~ ^selama[[:space:]]*\((.*)[[:space:]]*(==|!=|>=|<=|>|<)[[:space:]]*(.*)\)$ ]]; then
                    local op1="${BASH_REMATCH[1]}"
                    local cond="${BASH_REMATCH[2]}"
                    local op2="${BASH_REMATCH[3]}"
                    op1=$(echo "$op1" | xargs)
                    op2=$(echo "$op2" | xargs)
                    emit_loop_start "$op1" "$cond" "$op2"
                fi
                ;;

            "tutup_selama")
                emit_loop_end
                ;;

            cetak*)
                if [[ "$line" =~ ^cetak\(\"(.*)\"\) ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print "\"$content\""

                elif [[ "$line" =~ ^cetak\(([a-zA-Z0-9_]+)[[:space:]]*([-+*])[[:space:]]*([a-zA-Z0-9_]+)\)$ ]]; then
                    local op1="${BASH_REMATCH[1]}"
                    local op="${BASH_REMATCH[2]}"
                    local op2="${BASH_REMATCH[3]}"
                    emit_arithmetic_op "$op1" "$op" "$op2"

                elif [[ "$line" =~ ^cetak\(([a-zA-Z0-9_]+)\)$ ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print "$content"
                fi
                ;;

            # --- Assignment ke Variabel Ada (tanpa var) ---
            *)
                 if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local expr="${BASH_REMATCH[2]}"

                    if [[ "$expr" =~ ^([a-zA-Z0-9_]+)[[:space:]]*([-+*])[[:space:]]*([a-zA-Z0-9_]+)$ ]]; then
                         local op1="${BASH_REMATCH[1]}"
                         local op="${BASH_REMATCH[2]}"
                         local op2="${BASH_REMATCH[3]}"
                         emit_arithmetic_op "$op1" "$op" "$op2" "$name"
                    else
                        if [[ ! "$expr" =~ ^[0-9]+$ ]]; then
                           load_operand_to_rax "$expr"
                           emit_variable_assign "$name" ""
                        else
                           emit_variable_assign "$name" "$expr"
                        fi
                    fi
                 fi
                 ;;
        esac
    done < "$input_file"

    emit_output
}
