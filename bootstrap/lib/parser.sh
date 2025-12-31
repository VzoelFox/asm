# Fungsi parsing

# Note: codegen.sh should be sourced by the main script before this.

# Symbol Table Arrays (Global)
declare -A STRUCT_SIZES
declare -A STRUCT_OFFSETS
declare -A VAR_TYPE_MAP

# Global flag to track if we are parsing the main file
IS_MAIN_FILE=1
LINE_NO=0

# Block Stack for Validation
declare -a BLOCK_STACK

push_block() {
    BLOCK_STACK+=("$1")
}

pop_block() {
    local expected="$1"
    local len=${#BLOCK_STACK[@]}
    if [ $len -eq 0 ]; then
        echo "Error on line $LINE_NO: Unexpected '$expected'. No block open." >&2
        exit 1
    fi
    local actual="${BLOCK_STACK[$len-1]}"
    if [ "$actual" != "$expected" ]; then
        echo "Error on line $LINE_NO: Mismatched block closer. Expected to close '$actual' but found '$expected'." >&2
        exit 1
    fi
    unset 'BLOCK_STACK[$len-1]'
}

parse_file() {
    local input_file="$1"
    local is_entry_point=0

    # Only init codegen if this is the main file entry point
    if [ "$IS_MAIN_FILE" -eq 1 ]; then
        is_entry_point=1
        IS_MAIN_FILE=0
        init_codegen
    fi

    local in_asm_block=0
    local in_data_block=0
    local in_struct_block=0
    local current_struct_name=""

    # Reset Line Counter for this file? No, global might be confusing if recursive.
    # But recursive calls parse_file.
    # Let's use local LINE_NO per file context if possible? No, bash vars are global or local.
    # We will just increment global LINE_NO or reset it per file but handle errors relative to current file being parsed.
    # Simpler: just track line number in the loop.

    local CURRENT_FILE_LINE=0

    while IFS= read -r line || [ -n "$line" ]; do
        ((CURRENT_FILE_LINE++))
        LINE_NO=$CURRENT_FILE_LINE # Update global for helper access if needed

        # Trim whitespace
        line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')

        # Replace 'benar' with 1, 'salah' with 0 (Boolean Support)
        if [[ "$line" != *"\""* ]]; then
            line="${line//benar/1}"
            line="${line//salah/0}"
        fi

        # Skip empty and comments
        if [ -z "$line" ] || [[ "$line" =~ ^\; ]]; then continue; fi

        # Track function name BEFORE processing line if it's a function declaration
        if [[ "$line" =~ ^fungsi[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\( ]]; then
            CURRENT_FUNC_NAME="${BASH_REMATCH[1]}"
        fi

        # --- Handle Blocks (ASM & Data & Struct) ---
        if [ "$in_asm_block" -eq 1 ]; then
            if [ "$line" == "tutup_asm" ]; then
                in_asm_block=0
                pop_block "asm_mulai"
            else
                emit_raw_asm "$line"
            fi
            continue
        fi

        if [ "$in_struct_block" -eq 1 ]; then
            if [ "$line" == "tutup_struktur" ]; then
                in_struct_block=0
                pop_block "struktur"
            elif [ "$line" == "akhir" ]; then
                echo "Error on line $CURRENT_FILE_LINE: Deprecated keyword 'akhir'. Use 'tutup_struktur'." >&2
                exit 1
            else
                # Parse field: name type
                if [[ "$line" =~ ^([a-zA-Z0-9_]+)[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
                    local field_name="${BASH_REMATCH[1]}"
                    local current_size=${STRUCT_SIZES[$current_struct_name]}
                    STRUCT_OFFSETS["${current_struct_name}_${field_name}"]=$current_size
                    STRUCT_SIZES[$current_struct_name]=$((current_size + 8))
                fi
            fi
            continue
        fi

        if [ "$in_data_block" -eq 1 ]; then
            if [ "$line" == "tutup_data" ]; then
                in_data_block=0
                pop_block "asm_data"
            else
                emit_raw_data_fixed "$line"
            fi
            continue
        fi

        # --- Handle Normal Statements ---
        case "$line" in
            # Import (ambil)
            ambil*)
                if [[ "$line" =~ ^ambil[[:space:]]+\"(.*)\" ]]; then
                    local import_path="${BASH_REMATCH[1]}"
                    if [[ "$import_path" != *.fox ]]; then
                        import_path="$import_path.fox"
                    fi
                    if [ -f "$import_path" ]; then
                        parse_file "$import_path"
                    else
                        echo "; Error: Import file not found: $import_path"
                    fi
                fi
                ;;

            # Struktur Definisi
            struktur*)
                if [[ "$line" =~ ^struktur[[:space:]]+([a-zA-Z0-9_]+) ]]; then
                    current_struct_name="${BASH_REMATCH[1]}"
                    in_struct_block=1
                    STRUCT_SIZES[$current_struct_name]=0
                    push_block "struktur"
                fi
                ;;

            # fungsi nama(arg1, arg2)
            fungsi*)
                if [[ "$line" =~ ^fungsi[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\((.*)\)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local args="${BASH_REMATCH[2]}"

                    emit_function_start "$name"
                    push_block "fungsi"

                    # Handle Arguments: Declare them as variables and assign from registers
                    # Argument passing convention:
                    # 1st arg -> rdi
                    # 2nd arg -> rsi
                    # 3rd arg -> rdx
                    # 4th arg -> rcx
                    # 5th arg -> r8
                    # 6th arg -> r9

                    if [[ -n "$args" ]]; then
                        IFS=',' read -ra ARG_LIST <<< "$args"
                        local arg_count=0
                        for arg in "${ARG_LIST[@]}"; do
                            arg=$(echo "$arg" | xargs)
                            emit_variable_decl "$arg"

                            # Emit move from register to variable
                            case "$arg_count" in
                                0) echo "    mov [var_$arg], rdi" ;;
                                1) echo "    mov [var_$arg], rsi" ;;
                                2) echo "    mov [var_$arg], rdx" ;;
                                3) echo "    mov [var_$arg], rcx" ;;
                                4) echo "    mov [var_$arg], r8" ;;
                                5) echo "    mov [var_$arg], r9" ;;
                                *) echo "; Warning: Too many arguments (max 6 supported)" ;;
                            esac
                            ((arg_count++))
                        done
                    fi
                fi
                ;;

            "tutup_fungsi")
                emit_function_end "$CURRENT_FUNC_NAME"
                pop_block "fungsi"
                ;;

            "simpan")
                emit_snapshot
                ;;

            "kembalikan")
                emit_restore
                ;;

            "asm_mulai")
                in_asm_block=1
                push_block "asm_mulai"
                ;;
            "asm_data")
                in_data_block=1
                push_block "asm_data"
                ;;

            # --- Call (panggil) ---
            panggil*)
                if [[ "$line" =~ ^panggil[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\((.*)\)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local args="${BASH_REMATCH[2]}"

                    # Handle Argument Passing
                    if [[ -n "$args" ]]; then
                        IFS=',' read -ra VAL_LIST <<< "$args"
                        local arg_count=0
                        for val in "${VAL_LIST[@]}"; do
                            val=$(echo "$val" | xargs)

                            # Move value to register
                            local target_reg=""
                            case "$arg_count" in
                                0) target_reg="rdi" ;;
                                1) target_reg="rsi" ;;
                                2) target_reg="rdx" ;;
                                3) target_reg="rcx" ;;
                                4) target_reg="r8" ;;
                                5) target_reg="r9" ;;
                            esac

                            if [[ -n "$target_reg" ]]; then
                                if [[ "$val" =~ ^-?[0-9]+$ ]]; then
                                    echo "    mov $target_reg, $val"
                                else
                                    echo "    mov $target_reg, [var_$val]"
                                fi
                            fi
                            ((arg_count++))
                        done
                    fi

                    emit_call "$name"
                fi
                ;;

            # --- Variabel (Deklarasi) ---
            var*)
                # Array Declaration
                if [[ "$line" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+\[([0-9]+)\]int$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local size="${BASH_REMATCH[2]}"
                    emit_variable_decl "$name"
                    emit_array_alloc "$size"
                    emit_variable_assign "$name" ""

                # Normal Variable
                elif [[ "$line" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local expr="${BASH_REMATCH[2]}"

                    emit_variable_decl "$name"

                    if [[ "$expr" =~ ^([a-zA-Z0-9_]+)\((.*)\)$ ]]; then
                         local struct_name="${BASH_REMATCH[1]}"
                         local args_str="${BASH_REMATCH[2]}"

                         if [[ "$struct_name" == "baca" ]]; then
                             emit_read "$args_str"
                             emit_variable_assign "$name" ""
                         elif [[ "$struct_name" == "str_concat" ]]; then
                             IFS=',' read -ra ADDR <<< "$args_str"
                             local arg1=$(echo "${ADDR[0]}" | xargs)
                             local arg2=$(echo "${ADDR[1]}" | xargs)
                             emit_str_concat "$arg1" "$arg2"
                             emit_variable_assign "$name" ""
                         elif [[ -n "${STRUCT_SIZES[$struct_name]}" ]]; then
                             local size=${STRUCT_SIZES[$struct_name]}
                             IFS=',' read -ra ADDR <<< "$args_str"
                             local offsets_str=""
                             local values_str=""
                             local current_offset=0
                             for val in "${ADDR[@]}"; do
                                 val=$(echo "$val" | xargs)
                                 offsets_str="$offsets_str $current_offset"
                                 values_str="$values_str $val"
                                 current_offset=$((current_offset + 8))
                             done
                             emit_struct_alloc_and_init "$size" "$offsets_str" "$values_str"
                             emit_variable_assign "$name" ""
                             VAR_TYPE_MAP["$name"]="$struct_name"
                         else
                             # Function Call Result? (Not implemented fully)
                             :
                         fi
                    elif [[ "$expr" =~ ^([a-zA-Z0-9_]+)[[:space:]]*([-+*])[[:space:]]*([a-zA-Z0-9_]+)$ ]]; then
                         local op1="${BASH_REMATCH[1]}"
                         local op="${BASH_REMATCH[2]}"
                         local op2="${BASH_REMATCH[3]}"
                         emit_arithmetic_op "$op1" "$op" "$op2" "$name"
                    else
                        if [[ "$expr" =~ ^\"(.*)\"$ ]]; then
                           local content="${BASH_REMATCH[1]}"
                           emit_string_literal_assign "$name" "$content"
                        elif [[ ! "$expr" =~ ^-?[0-9]+$ ]]; then
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
                    push_block "jika"
                fi
                ;;

            "tutup_jika")
                emit_if_end
                pop_block "jika"
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
                    push_block "selama"
                fi
                ;;

            "tutup_selama")
                emit_loop_end
                pop_block "selama"
                ;;

            cetak_str*)
                if [[ "$line" =~ ^cetak_str\(([a-zA-Z0-9_]+)\)$ ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print_str "$content"
                fi
                ;;

            cetak*)
                if [[ "$line" =~ ^cetak\(\"(.*)\"\) ]]; then
                    local content="${BASH_REMATCH[1]}"
                    emit_print "\"$content\""
                elif [[ "$line" =~ ^cetak\(([a-zA-Z0-9_]+)\[([a-zA-Z0-9_]+)\]\)$ ]]; then
                    local var_name="${BASH_REMATCH[1]}"
                    local index="${BASH_REMATCH[2]}"
                    emit_load_array_elem "$var_name" "$index"
                    emit_print ""
                elif [[ "$line" =~ ^cetak\(([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\)$ ]]; then
                    local var_name="${BASH_REMATCH[1]}"
                    local field_name="${BASH_REMATCH[2]}"
                    local struct_name="${VAR_TYPE_MAP[$var_name]}"
                    if [[ -n "$struct_name" ]]; then
                        local offset="${STRUCT_OFFSETS[${struct_name}_${field_name}]}"
                        if [[ -n "$offset" ]]; then
                             emit_load_struct_field "$var_name" "$offset"
                             emit_print ""
                        fi
                    fi
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
                 if [[ "$line" =~ ^([a-zA-Z0-9_]+)\[([a-zA-Z0-9_]+)\][[:space:]]*=[[:space:]]*(.*)$ ]]; then
                     local var_name="${BASH_REMATCH[1]}"
                     local index="${BASH_REMATCH[2]}"
                     local val="${BASH_REMATCH[3]}"
                     emit_store_array_elem "$var_name" "$index" "$val"
                 elif [[ "$line" =~ ^([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                     local var_name="${BASH_REMATCH[1]}"
                     local field_name="${BASH_REMATCH[2]}"
                     local val="${BASH_REMATCH[3]}"
                     local struct_name="${VAR_TYPE_MAP[$var_name]}"
                     if [[ -n "$struct_name" ]]; then
                         local offset="${STRUCT_OFFSETS[${struct_name}_${field_name}]}"
                         if [[ -n "$offset" ]]; then
                             emit_store_struct_field "$var_name" "$offset" "$val"
                         fi
                     fi
                 elif [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
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

    if [ "$is_entry_point" -eq 1 ]; then
        emit_output
    fi
}
