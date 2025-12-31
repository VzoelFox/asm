# Fungsi parsing

# Note: codegen.sh should be sourced by the main script before this.

# Symbol Table Arrays (Global)
declare -A STRUCT_SIZES
declare -A STRUCT_OFFSETS
declare -A VAR_TYPE_MAP

# Global flag to track if we are parsing the main file
IS_MAIN_FILE=1

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

    while IFS= read -r line || [ -n "$line" ]; do
        # Trim whitespace
        line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')

        # Replace 'benar' with 1, 'salah' with 0 (Boolean Support)
        # Note: simplistic replacement, might match strings if not careful
        # Ideally should only replace tokens.
        # sed "s/\bbenar\b/1/g" is not standard in minimal sed
        # Using pure bash substitution with patterns
        if [[ "$line" != *"\""* ]]; then # Avoid replacing inside strings for now (simplification)
            line="${line//benar/1}"
            line="${line//salah/0}"
        fi

        # Skip empty
        if [ -z "$line" ]; then continue; fi

        # Track function name BEFORE processing line if it's a function declaration
        if [[ "$line" =~ ^fungsi[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\( ]]; then
            CURRENT_FUNC_NAME="${BASH_REMATCH[1]}"
        fi

        # --- Handle Blocks (ASM & Data & Struct) ---
        if [ "$in_asm_block" -eq 1 ]; then
            if [ "$line" == "tutup_asm" ]; then
                in_asm_block=0
            else
                emit_raw_asm "$line"
            fi
            continue
        fi

        if [ "$in_struct_block" -eq 1 ]; then
            if [ "$line" == "akhir" ]; then
                in_struct_block=0
                # Finalize struct size
                # echo "Struct $current_struct_name size: ${STRUCT_SIZES[$current_struct_name]}"
            else
                # Parse field: name type
                # Example: x int
                if [[ "$line" =~ ^([a-zA-Z0-9_]+)[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
                    local field_name="${BASH_REMATCH[1]}"
                    # local field_type="${BASH_REMATCH[2]}"

                    local current_size=${STRUCT_SIZES[$current_struct_name]}

                    # Map: STRUCT_OFFSETS_StructName_FieldName = Offset
                    STRUCT_OFFSETS["${current_struct_name}_${field_name}"]=$current_size

                    # Increment size (always 8 bytes for now)
                    STRUCT_SIZES[$current_struct_name]=$((current_size + 8))
                fi
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
            # Import (ambil)
            ambil*)
                if [[ "$line" =~ ^ambil[[:space:]]+\"(.*)\" ]]; then
                    local import_path="${BASH_REMATCH[1]}"
                    # Check extension
                    if [[ "$import_path" != *.fox ]]; then
                        import_path="$import_path.fox"
                    fi

                    # Recursive parse
                    # We are already inside parse_file, so IS_MAIN_FILE is 0 globally now.
                    # Just call it.
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
                    # echo "DEBUG: Found struct $current_struct_name"
                fi
                ;;

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

            # --- Baca (Input) ---
            baca*)
                # Usage: var x = baca(100)
                # But here we handle standalone? Usually part of assignment.
                # Let's handle it in assignment block below?
                # Or just regex match specifically if used standalone (unlikely to be useful).
                ;;

            # --- Variabel (Deklarasi) ---
            var*)
                # Array Declaration: var arr [10]int
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

                    # Check for struct instantiation: Point(1, 2)
                    # Regex: Name(Args)
                    if [[ "$expr" =~ ^([a-zA-Z0-9_]+)\((.*)\)$ ]]; then
                         local struct_name="${BASH_REMATCH[1]}"
                         local args_str="${BASH_REMATCH[2]}"

                         # Check if it is a struct or built-in 'baca'
                         if [[ "$struct_name" == "baca" ]]; then
                             emit_read "$args_str"
                             emit_variable_assign "$name" ""
                         elif [[ "$struct_name" == "str_concat" ]]; then
                             # str_concat(a, b)
                             IFS=',' read -ra ADDR <<< "$args_str"
                             local arg1=$(echo "${ADDR[0]}" | xargs)
                             local arg2=$(echo "${ADDR[1]}" | xargs)
                             emit_str_concat "$arg1" "$arg2"
                             emit_variable_assign "$name" ""
                         elif [[ -n "${STRUCT_SIZES[$struct_name]}" ]]; then
                             # Struct Instantiation
                             local size=${STRUCT_SIZES[$struct_name]}

                             # Parse args (comma separated)
                             # Note: Bash regex doesn't support repeating groups well.
                             # Simple split by comma.
                             IFS=',' read -ra ADDR <<< "$args_str"

                             local offsets_str=""
                             local values_str=""
                             local current_offset=0

                             for val in "${ADDR[@]}"; do
                                 # Trim
                                 val=$(echo "$val" | xargs)
                                 offsets_str="$offsets_str $current_offset"
                                 values_str="$values_str $val"
                                 current_offset=$((current_offset + 8))
                             done

                             emit_struct_alloc_and_init "$size" "$offsets_str" "$values_str"
                             emit_variable_assign "$name" ""

                             # Store variable type for member access
                             VAR_TYPE_MAP["$name"]="$struct_name"
                         else
                             # Function call? Or error?
                             # For now assume everything else is not handled or func result (TODO)
                             :
                         fi
                    elif [[ "$expr" =~ ^([a-zA-Z0-9_]+)[[:space:]]*([-+*])[[:space:]]*([a-zA-Z0-9_]+)$ ]]; then
                         local op1="${BASH_REMATCH[1]}"
                         local op="${BASH_REMATCH[2]}"
                         local op2="${BASH_REMATCH[3]}"
                         emit_arithmetic_op "$op1" "$op" "$op2" "$name"
                    else
                        # Check for string literal
                        if [[ "$expr" =~ ^\"(.*)\"$ ]]; then
                           local content="${BASH_REMATCH[1]}"
                           # We need to emit this string to data section and get pointer
                           # Reuse emit_print mechanism logic?
                           # Better: create emit_string_literal_assign
                           emit_string_literal_assign "$name" "$content"
                        # Check for number (positive or negative)
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
                    # Array Access Print: cetak(arr[i])
                    local var_name="${BASH_REMATCH[1]}"
                    local index="${BASH_REMATCH[2]}"
                    emit_load_array_elem "$var_name" "$index"
                    emit_print ""

                elif [[ "$line" =~ ^cetak\(([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\)$ ]]; then
                    # Struct field access print: cetak(p.x)
                    local var_name="${BASH_REMATCH[1]}"
                    local field_name="${BASH_REMATCH[2]}"

                    local struct_name="${VAR_TYPE_MAP[$var_name]}"
                    if [[ -n "$struct_name" ]]; then
                        local offset="${STRUCT_OFFSETS[${struct_name}_${field_name}]}"
                        if [[ -n "$offset" ]]; then
                             emit_load_struct_field "$var_name" "$offset"
                             # Result in RAX, print implicit
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
                 # Array Assignment: arr[i] = 100
                 if [[ "$line" =~ ^([a-zA-Z0-9_]+)\[([a-zA-Z0-9_]+)\][[:space:]]*=[[:space:]]*(.*)$ ]]; then
                     local var_name="${BASH_REMATCH[1]}"
                     local index="${BASH_REMATCH[2]}"
                     local val="${BASH_REMATCH[3]}"
                     emit_store_array_elem "$var_name" "$index" "$val"

                 # Struct Field Assignment: p.x = 100
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
