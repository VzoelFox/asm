# Fungsi parsing

# Note: codegen.sh should be sourced by the main script before this.

# Symbol Table Arrays (Global)
declare -A STRUCT_SIZES
declare -A STRUCT_OFFSETS
declare -A VAR_TYPE_MAP

# Import Guard Arrays (Global)
declare -A PROCESSED_FILES
declare -A PROCESSED_BLOCKS

# ID Registry (Global Map: ID -> Filepath)
declare -A ID_MAP

# Global flag to track if we are parsing the main file
IS_MAIN_FILE=1
LINE_NO=0

# Block Stack for Validation
declare -a BLOCK_STACK
declare -a FOR_STEP_STACK # Stack to hold step expressions for 'untuk' loops
declare -a SWITCH_VAL_STACK   # Stack to hold the variable name being switched on
declare -a SWITCH_FIRST_STACK # Stack to track if we are at the first case (1=yes, 0=no)
declare -a FUNC_ARGS_STACK    # Stack to hold function arguments for recursion save/restore

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

extract_block_by_id() {
    local file="$1"
    local id="$2"

    # Logic: Scan file for "### <id>"
    # Print lines until next "###" or EOF

    local in_target_block=0

    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "; Error: File not found for extraction: $file" >&2
        return
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        # Check for marker
        if [[ "$line" =~ ^###[[:space:]]*([0-9]+) ]]; then
            local current_id="${BASH_REMATCH[1]}"
            if [ "$current_id" == "$id" ]; then
                in_target_block=1
                continue # Skip the marker line itself
            else
                if [ "$in_target_block" -eq 1 ]; then
                    # Hit next marker, stop
                    break
                fi
                in_target_block=0
            fi
        fi

        if [ "$in_target_block" -eq 1 ]; then
            echo "$line"
        fi
    done < "$file"
}

resolve_struct_access() {
    local expr="$1"
    local ret_var_name="$2"

    if [[ "$expr" =~ ^([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)$ ]]; then
        local s_var="${BASH_REMATCH[1]}"
        local s_field="${BASH_REMATCH[2]}"
        local s_type="${VAR_TYPE_MAP[$s_var]}"

        if [[ -n "$s_type" ]]; then
            local offset="${STRUCT_OFFSETS[${s_type}_${s_field}]}"
            if [[ -n "$offset" ]]; then
                local tmp="tmp_s_${LINE_NO}_$RANDOM"
                emit_variable_decl "$tmp"
                emit_load_struct_field "$s_var" "$offset"
                echo "    mov [var_$tmp], rax"
                eval "$ret_var_name='$tmp'"
                return 0
            fi
        fi
    fi
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

    local CURRENT_FILE_LINE=0

    while IFS= read -r line || [ -n "$line" ]; do
        ((CURRENT_FILE_LINE++))
        LINE_NO=$CURRENT_FILE_LINE

        # Strip inline comments (e.g., "cmd ; comment" -> "cmd ")
        # EXCEPTION: 'untuk' uses ';' as separator, so we skip comment stripping for 'untuk' lines
        # Also need to handle indentation
        if [[ ! "$line" =~ ^[[:space:]]*untuk ]]; then
            if [[ "$line" != *"\""* ]]; then
                 line="${line%%;*}"
            else
                 # If string exists, naive strip might break string content.
                 # Assuming no semicolon in string for now unless it's strictly needed.
                 # Only strip if ; is after the last quote? Too complex for sed/bash here.
                 # Fallback: maintain naive strip for now, assuming standard code style.
                 line="${line%%;*}"
            fi
        fi

        # Trim whitespace (and remove CR for Windows compatibility)
        line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//' | tr -d '\r')

        # Replace 'benar' with 1, 'salah' with 0 (Boolean Support)
        if [[ "$line" != *"\""* ]]; then
            line="${line//benar/1}"
            line="${line//salah/0}"
        fi

        # Skip empty
        if [ -z "$line" ]; then continue; fi

        # Check for Markers ### (handled by extract, but if parsing full file?)
        if [[ "$line" =~ ^### ]]; then continue; fi

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
                if [[ "$line" =~ ^([a-zA-Z0-9_]+)[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
                    local field_name="${BASH_REMATCH[1]}"
                    local current_size=${STRUCT_SIZES[$current_struct_name]}
                    STRUCT_OFFSETS["${current_struct_name}_${field_name}"]=$current_size
                    STRUCT_SIZES[$current_struct_name]=$((current_size + 8))
                    echo "; DEBUG: Struct $current_struct_name Field $field_name Offset $current_size"
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
            # Indeks (Load Tagger Index)
            indeks*)
                if [[ "$line" =~ ^indeks[[:space:]]+\"(.*)\" ]]; then
                    local index_path="${BASH_REMATCH[1]}"
                    # Just recursively parse the tagger file
                    # Tagger file contains 'Daftar' commands which update ID_MAP
                    if [ -f "$index_path" ]; then
                        parse_file "$index_path"
                    else
                        echo "; Error: Index file not found: $index_path"
                    fi
                fi
                ;;

            # Daftar <Path> = <Range/ID> (Registration)
            Daftar*)
                # Format: Daftar "lib/math.fox" = 100-105
                # Regex needs to be flexible
                if [[ "$line" =~ ^Daftar[[:space:]]+\"(.*)\"[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                    local target_file="${BASH_REMATCH[1]}"
                    local range_str="${BASH_REMATCH[2]}"

                    # Ensure extension
                    if [[ "$target_file" != *.fox ]]; then target_file="$target_file.fox"; fi

                    # Parse Range/List (Comma separated)
                    IFS=',' read -ra RANGES <<< "$range_str"
                    for r in "${RANGES[@]}"; do
                        r=$(echo "$r" | xargs) # Trim
                        if [[ "$r" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                            # Range: Start-End
                            local start="${BASH_REMATCH[1]}"
                            local end="${BASH_REMATCH[2]}"
                            for (( i=start; i<=end; i++ )); do
                                ID_MAP[$i]="$target_file"
                            done
                        elif [[ "$r" =~ ^([0-9]+)$ ]]; then
                            # Single ID
                            local id="${BASH_REMATCH[1]}"
                            ID_MAP[$id]="$target_file"
                        fi
                    done
                fi
                ;;

            # Import (Ambil - Capitalized) ID-based & Global Registry
            Ambil*)
                # Format: Ambil "filepath" 1, 2  (Explicit File)
                # Format: Ambil 100, 101         (Global ID Lookup)

                # Check for explicit filepath first (contains quote)
                if [[ "$line" =~ ^Ambil[[:space:]]+\"(.*)\"[[:space:]]+(.*)$ ]]; then
                    local import_path="${BASH_REMATCH[1]}"
                    local ids="${BASH_REMATCH[2]}"
                    if [[ "$import_path" != *.fox ]]; then import_path="$import_path.fox"; fi

                    if [ -f "$import_path" ]; then
                        IFS=',' read -ra ID_LIST <<< "$ids"
                        for id in "${ID_LIST[@]}"; do
                            id=$(echo "$id" | xargs)
                            local block_key="${import_path}:${id}"
                            if [ "${PROCESSED_BLOCKS[$block_key]}" == "1" ]; then continue; fi
                            PROCESSED_BLOCKS[$block_key]=1
                            local tmp_file="_import_${id}_$$.fox"
                            extract_block_by_id "$import_path" "$id" > "$tmp_file"
                            parse_file "$tmp_file"
                            rm "$tmp_file"
                        done
                    else
                        echo "; Error: Import file not found: $import_path"
                    fi

                # Check for Global ID List (only numbers and commas)
                elif [[ "$line" =~ ^Ambil[[:space:]]+([0-9,[:space:]]+)$ ]]; then
                    local ids="${BASH_REMATCH[1]}"
                    IFS=',' read -ra ID_LIST <<< "$ids"
                    for id in "${ID_LIST[@]}"; do
                        id=$(echo "$id" | xargs)

                        # Lookup in ID_MAP
                        local mapped_file="${ID_MAP[$id]}"
                        if [ -n "$mapped_file" ]; then
                            # Found mapping!
                            local block_key="${mapped_file}:${id}"
                            if [ "${PROCESSED_BLOCKS[$block_key]}" == "1" ]; then continue; fi
                            PROCESSED_BLOCKS[$block_key]=1

                            local tmp_file="_import_${id}_$$.fox"
                            extract_block_by_id "$mapped_file" "$id" > "$tmp_file"
                            parse_file "$tmp_file"
                            rm "$tmp_file"
                        else
                            echo "; Error: ID $id not found in registry. Did you load 'indeks'?"
                        fi
                    done
                fi
                ;;

            # Import (ambil - lowercase) File-based
            ambil*)
                if [[ "$line" =~ ^ambil[[:space:]]+\"(.*)\" ]]; then
                    local import_path="${BASH_REMATCH[1]}"
                    if [[ "$import_path" != *.fox ]]; then
                        import_path="$import_path.fox"
                    fi

                    # GUARD: Check if file already processed
                    if [ "${PROCESSED_FILES[$import_path]}" == "1" ]; then
                        :
                    else
                        PROCESSED_FILES[$import_path]=1
                        if [ -f "$import_path" ]; then
                            parse_file "$import_path"
                        else
                            echo "; Error: Import file not found: $import_path"
                        fi
                    fi
                fi
                ;;

            # ... (Rest of existing handlers: struktur, fungsi, var, jika, loop, cetak, assignment) ...
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

                    # Store args for restore later
                    FUNC_ARGS_STACK+=("$args")

                    if [[ -n "$args" ]]; then
                        IFS=',' read -ra ARG_LIST <<< "$args"
                        local arg_count=0
                        for arg in "${ARG_LIST[@]}"; do
                            arg=$(echo "$arg" | xargs)
                            emit_variable_decl "$arg"

                            # RECURSION FIX: Save old value of the global var argument to stack
                            echo "    push qword [var_$arg]"

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
                # RECURSION FIX: Restore old values of arguments from stack (Reverse Order)
                local len=${#FUNC_ARGS_STACK[@]}
                if [ $len -gt 0 ]; then
                    local args="${FUNC_ARGS_STACK[$len-1]}"
                    if [[ -n "$args" ]]; then
                        IFS=',' read -ra ARG_LIST <<< "$args"
                        # Loop in reverse
                        for (( i=${#ARG_LIST[@]}-1; i>=0; i-- )); do
                            local arg=$(echo "${ARG_LIST[$i]}" | xargs)
                            echo "    pop qword [var_$arg]"
                        done
                    fi
                    unset 'FUNC_ARGS_STACK[$len-1]'
                fi

                emit_function_end "$CURRENT_FUNC_NAME"
                pop_block "fungsi"
                ;;

            return*)
                if [[ "$line" =~ ^return[[:space:]]+(.*)$ ]]; then
                    local val="${BASH_REMATCH[1]}"

                    # 1. Load Return Value to RAX
                    if [[ "$val" =~ ^-?[0-9]+$ ]]; then
                        echo "    mov rax, $val"
                    else
                        echo "    mov rax, [var_$val]"
                    fi

                    # 2. Restore Arguments (Recursion Fix)
                    local len=${#FUNC_ARGS_STACK[@]}
                    if [ $len -gt 0 ]; then
                        local args="${FUNC_ARGS_STACK[$len-1]}"
                        if [[ -n "$args" ]]; then
                            IFS=',' read -ra ARG_LIST <<< "$args"
                            # Loop in reverse
                            for (( i=${#ARG_LIST[@]}-1; i>=0; i-- )); do
                                local arg=$(echo "${ARG_LIST[$i]}" | xargs)
                                echo "    pop qword [var_$arg]"
                            done
                        fi
                    fi

                    # 3. Return
                    echo "    ret"
                fi
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

                    if [[ -n "$args" ]]; then
                        IFS=',' read -ra VAL_LIST <<< "$args"
                        local arg_count=0
                        for val in "${VAL_LIST[@]}"; do
                            # Use sed to trim spaces while preserving quotes
                            val=$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

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
                                if [[ "$val" =~ ^\"(.*)\"$ ]]; then
                                    # String Literal support for panggil
                                    local content="${BASH_REMATCH[1]}"
                                    local label="str_arg_p_${LINE_NO}_${arg_count}"
                                    emit_raw_data_fixed "$label db \`$content\`, 0"
                                    echo "    mov $target_reg, $label"
                                elif [[ "$val" =~ ^-?[0-9]+$ ]]; then
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
            # --- Type Casting / Hinting ---
            tipe*)
                if [[ "$line" =~ ^tipe[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
                    local var_name="${BASH_REMATCH[1]}"
                    local struct_name="${BASH_REMATCH[2]}"

                    if [[ -n "${STRUCT_SIZES[$struct_name]}" ]]; then
                        VAR_TYPE_MAP["$var_name"]="$struct_name"
                        # No assembly emission needed, purely metadata update
                    else
                         echo "; Warning: Unknown struct type '$struct_name' in 'tipe' declaration."
                    fi
                fi
                ;;

            var*)
                if [[ "$line" =~ ^var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+\[([0-9]+)\]int$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local size="${BASH_REMATCH[2]}"
                    emit_variable_decl "$name"
                    emit_array_alloc "$size"
                    emit_variable_assign "$name" ""

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
                         elif [[ "$struct_name" == "str_eq" ]]; then
                             IFS=',' read -ra ADDR <<< "$args_str"
                             local arg1=$(echo "${ADDR[0]}" | xargs)
                             local arg2=$(echo "${ADDR[1]}" | xargs)
                             emit_str_eq "$arg1" "$arg2"
                             emit_variable_assign "$name" ""
                         elif [[ "$struct_name" == "str_get" ]]; then
                             IFS=',' read -ra ADDR <<< "$args_str"
                             local arg1=$(echo "${ADDR[0]}" | xargs)
                             local arg2=$(echo "${ADDR[1]}" | xargs)
                             emit_str_get "$arg1" "$arg2"
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
                             # Generic Function Call in Assignment
                             # Handle Arguments (Same as panggil but with string literal support)
                             if [[ -n "$args_str" ]]; then
                                 IFS=',' read -ra VAL_LIST <<< "$args_str"
                                 local arg_count=0
                                 for val in "${VAL_LIST[@]}"; do
                                     # Use sed to trim spaces while preserving quotes
                                     val=$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

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
                                         if [[ "$val" =~ ^\"(.*)\"$ ]]; then
                                             # String Literal
                                             local content="${BASH_REMATCH[1]}"
                                             local label="str_arg_${LINE_NO}_${arg_count}"
                                             emit_raw_data_fixed "$label db \`$content\`, 0"
                                             echo "    mov $target_reg, $label"
                                         elif [[ "$val" =~ ^-?[0-9]+$ ]]; then
                                             echo "    mov $target_reg, $val"
                                         else
                                             echo "    mov $target_reg, [var_$val]"
                                         fi
                                     fi
                                     ((arg_count++))
                                 done
                             fi
                             emit_call "$struct_name"
                             emit_variable_assign "$name" ""
                         fi
                    elif [[ "$expr" =~ ^([a-zA-Z0-9_]+)[[:space:]]*([-+*/%&|^])[[:space:]]*([a-zA-Z0-9_]+)$ ]]; then
                         local op1="${BASH_REMATCH[1]}"
                         local op="${BASH_REMATCH[2]}"
                         local op2="${BASH_REMATCH[3]}"
                         emit_arithmetic_op "$op1" "$op" "$op2" "$name"
                    elif [[ "$expr" =~ ^!([a-zA-Z0-9_]+)$ ]]; then
                         # Logical NOT
                         local op="${BASH_REMATCH[1]}"
                         emit_logical_not "$op" "$name"
                    elif [[ "$expr" =~ ^([a-zA-Z0-9_]+)\[([a-zA-Z0-9_]+)\]$ ]]; then
                         # Array Index Read: var x = arr[i]
                         local arr_name="${BASH_REMATCH[1]}"
                         local index="${BASH_REMATCH[2]}"
                         emit_load_array_elem "$arr_name" "$index"
                         emit_variable_assign "$name" ""
                    elif [[ "$expr" =~ ^([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)$ ]]; then
                         # Struct Field Access (RHS)
                         local struct_var="${BASH_REMATCH[1]}"
                         local field="${BASH_REMATCH[2]}"
                         local struct_type="${VAR_TYPE_MAP[$struct_var]}"

                         if [[ -n "$struct_type" ]]; then
                             local offset="${STRUCT_OFFSETS[${struct_type}_${field}]}"
                             if [[ -n "$offset" ]]; then
                                 emit_load_struct_field "$struct_var" "$offset"
                                 emit_variable_assign "$name" ""
                             else
                                 echo "; Error: Unknown field '$field' in struct '$struct_type'"
                             fi
                         else
                             # Fallback: Maybe it's not registered in VAR_TYPE_MAP (e.g. passed as arg)
                             # In that case we can't determine offset at compile time EASILY without type info.
                             # BUT, in 'map_put', 'map' is an argument. We don't know its type!
                             # This is a limitation of this untyped/simple parser.
                             # CRITICAL: We need a way to cast or know type.
                             # For now, we might need to assume or look up recursively? No.
                             #
                             # WORKAROUND: For arguments that are structs, we need to manually define offsets?
                             # Or we can check if 'map' matches known struct names? No.
                             #
                             # Wait, how does 'cetak(map.capacity)' work?
                             # It uses VAR_TYPE_MAP.
                             # If 'map' was passed as arg, it is NOT in VAR_TYPE_MAP.
                             # So 'cetak(map.capacity)' would also fail if 'map' is an argument!

                             echo "; Warning: Cannot resolve type for '$struct_var'. Assuming offset lookup fails."
                         fi
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
                    resolve_struct_access "$op1" op1
                    resolve_struct_access "$op2" op2
                    emit_if_start "$op1" "$cond" "$op2"
                    push_block "jika"
                fi
                ;;

            lain_jika*)
                if [[ "$line" =~ ^lain_jika[[:space:]]*\((.*)[[:space:]]*(==|!=|>=|<=|>|<)[[:space:]]*(.*)\)$ ]]; then
                    # Check if inside 'jika' block
                    local len=${#BLOCK_STACK[@]}
                    if [ $len -eq 0 ] || [ "${BLOCK_STACK[$len-1]}" != "jika" ]; then
                         echo "Error on line $LINE_NO: 'lain_jika' must be inside a 'jika' block." >&2
                         exit 1
                    fi

                    local op1="${BASH_REMATCH[1]}"
                    local cond="${BASH_REMATCH[2]}"
                    local op2="${BASH_REMATCH[3]}"
                    op1=$(echo "$op1" | xargs)
                    op2=$(echo "$op2" | xargs)
                    resolve_struct_access "$op1" op1
                    resolve_struct_access "$op2" op2
                    emit_else_if "$op1" "$cond" "$op2"
                fi
                ;;

            lain*)
                if [[ "$line" =~ ^lain$ ]]; then
                    # Check if inside 'jika' block
                    local len=${#BLOCK_STACK[@]}
                    if [ $len -eq 0 ] || [ "${BLOCK_STACK[$len-1]}" != "jika" ]; then
                         echo "Error on line $LINE_NO: 'lain' must be inside a 'jika' block." >&2
                         exit 1
                    fi
                    emit_else
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
                    resolve_struct_access "$op1" op1
                    resolve_struct_access "$op2" op2
                    emit_loop_start "$op1" "$cond" "$op2"
                    push_block "selama"
                fi
                ;;

            "tutup_selama")
                emit_loop_end
                pop_block "selama"
                ;;

            # --- Loop (Untuk) ---
            untuk*)
                if [[ "$line" =~ ^untuk[[:space:]]*\((.*)\)$ ]]; then
                    local content="${BASH_REMATCH[1]}"

                    # Split by semicolon using awk because bash read is tricky with escaped chars, but here logic is simple
                    # Note: We assume simple expressions without internal semicolons
                    local init=$(echo "$content" | awk -F';' '{print $1}' | xargs)
                    local cond=$(echo "$content" | awk -F';' '{print $2}' | xargs)
                    local step=$(echo "$content" | awk -F';' '{print $3}' | xargs)

                    # 1. Emit Init
                    # We can reuse the assignment parser logic by calling a helper or recursive parse on the string
                    # But simpler: just inject it as a "line" processing if it looks like assignment
                    if [[ -n "$init" ]]; then
                        # Hack: Process 'init' as if it was a line
                        # We need to handle 'var i = 0' or 'i = 0'
                        # Let's verify if it starts with 'var'
                        if [[ "$init" =~ ^var[[:space:]] ]]; then
                           # It's a declaration. We need to parse it manually or recurse?
                           # Recursing is dangerous if not careful.
                           # Let's duplicate the 'var' logic slightly or use a temp file?
                           # Temp file is safest for code reuse.
                           echo "$init" > "_tmp_init_$$.fox"
                           parse_file "_tmp_init_$$.fox"
                           rm "_tmp_init_$$.fox"
                        else
                           # Assume assignment without var
                           echo "$init" > "_tmp_init_$$.fox"
                           parse_file "_tmp_init_$$.fox"
                           rm "_tmp_init_$$.fox"
                        fi
                    fi

                    # 2. Start Loop Label
                    # We need to manually emit loop start because 'emit_loop_start' assumes a comparison args
                    # So we split 'cond' into op1, op, op2

                    # Try explicit matching for operators to be safe
                    local op=""
                    if [[ "$cond" == *"<="* ]]; then op="<=";
                    elif [[ "$cond" == *">="* ]]; then op=">=";
                    elif [[ "$cond" == *"=="* ]]; then op="==";
                    elif [[ "$cond" == *"!="* ]]; then op="!=";
                    elif [[ "$cond" == *"<"* ]]; then op="<";
                    elif [[ "$cond" == *">"* ]]; then op=">";
                    fi

                    if [[ -n "$op" ]]; then
                        # Split by operator
                        # Use awk to split by string is safer than regex in bash sometimes
                        local op1=$(echo "$cond" | awk -F"$op" '{print $1}' | xargs)
                        local op2=$(echo "$cond" | awk -F"$op" '{print $2}' | xargs)

                        resolve_struct_access "$op1" op1
                        resolve_struct_access "$op2" op2

                        emit_for_start "$op1" "$op" "$op2"
                    else
                        echo "; DEBUG: Operator not found in cond: '$cond'" >&2
                        echo "; Error: Invalid condition in 'untuk': $cond"
                    fi

                    push_block "untuk"
                    FOR_STEP_STACK+=("$step")
                fi
                ;;

            "tutup_untuk")
                # Emit Step Code
                local len=${#FOR_STEP_STACK[@]}

                # Emit Label Step (Target for 'lanjut')
                emit_label_step

                if [ $len -gt 0 ]; then
                    local step="${FOR_STEP_STACK[$len-1]}"
                    if [[ -n "$step" ]]; then
                        echo "$step" > "_tmp_step_$$.fox"
                        parse_file "_tmp_step_$$.fox"
                        rm "_tmp_step_$$.fox"
                    fi
                    unset 'FOR_STEP_STACK[$len-1]'
                fi

                emit_for_end
                pop_block "untuk"
                ;;

            # --- Switch / Case (Pilih / Kasus) ---
            # NOTE: pilihan_lain must be checked BEFORE pilih because 'pilih' matches 'pilihan...' prefix
            pilihan_lain*)
                if [[ "$line" =~ ^pilihan_lain:$ ]]; then
                    emit_else
                fi
                ;;

            pilih*)
                if [[ "$line" =~ ^pilih[[:space:]]*\((.*)\)$ ]]; then
                    local expr="${BASH_REMATCH[1]}"
                    local temp_var="_sw_tmp_${LINE_NO}_$RANDOM"

                    # Evaluate expr and store in temp variable

                    emit_variable_decl "$temp_var"

                    # Resolve struct access if needed
                    resolve_struct_access "$expr" expr

                    if [[ "$expr" =~ ^\"(.*)\"$ ]]; then
                       local content="${BASH_REMATCH[1]}"
                       emit_string_literal_assign "$temp_var" "$content"
                    elif [[ ! "$expr" =~ ^-?[0-9]+$ ]]; then
                       # It's a variable or complex expr?
                       # If it's a variable:
                       load_operand_to_rax "$expr"
                       emit_variable_assign "$temp_var" ""
                    else
                       # Literal int
                       emit_variable_assign "$temp_var" "$expr"
                    fi

                    push_block "pilih"
                    SWITCH_VAL_STACK+=("$temp_var")
                    SWITCH_FIRST_STACK+=("1")
                fi
                ;;

            kasus*)
                if [[ "$line" =~ ^kasus[[:space:]]+(.*):$ ]]; then
                    local val="${BASH_REMATCH[1]}"
                    val=$(echo "$val" | xargs) # Trim

                    # Get switch var
                    local len=${#SWITCH_VAL_STACK[@]}
                    if [ $len -eq 0 ]; then
                        echo "Error on line $LINE_NO: 'kasus' outside of 'pilih'." >&2
                        exit 1
                    fi
                    local sw_var="${SWITCH_VAL_STACK[$len-1]}"
                    local is_first="${SWITCH_FIRST_STACK[$len-1]}"

                    # Resolve struct access for value
                    resolve_struct_access "$val" val

                    if [ "$is_first" -eq 1 ]; then
                        # First case -> emit_if_start
                        emit_if_start "$sw_var" "==" "$val"
                        SWITCH_FIRST_STACK[$len-1]="0" # Mark as not first anymore
                    else
                        # Subsequent case -> emit_else_if
                        emit_else_if "$sw_var" "==" "$val"
                    fi
                fi
                ;;

            "tutup_pilih")
                # Close the implicit if-chain
                # But wait, if NO cases were defined, emit_if_end will fail/crash codegen (empty stack)?
                # We need to check if we ever opened an IF.
                # If SWITCH_FIRST_STACK is still 1, it means no cases.
                local len=${#SWITCH_FIRST_STACK[@]}
                local is_first="${SWITCH_FIRST_STACK[$len-1]}"

                if [ "$is_first" -eq 0 ]; then
                    emit_if_end
                fi

                unset 'SWITCH_VAL_STACK[$len-1]'
                unset 'SWITCH_FIRST_STACK[$len-1]'
                pop_block "pilih"
                ;;

            "berhenti")
                emit_break
                ;;

            "lanjut")
                emit_continue
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
                elif [[ "$line" =~ ^cetak\(([a-zA-Z0-9_]+)[[:space:]]*([-+*/%])[[:space:]]*([a-zA-Z0-9_]+)\)$ ]]; then
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
                 if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\((.*)\)$ ]]; then
                    # Implicit Function Call (Standalone)
                    local name="${BASH_REMATCH[1]}"
                    local args="${BASH_REMATCH[2]}"

                    # Ignore if it's a keyword that wasn't caught (sanity check)
                    if [[ "$name" != "jika" && "$name" != "selama" && "$name" != "lain_jika" ]]; then
                        if [[ -n "$args" ]]; then
                            IFS=',' read -ra VAL_LIST <<< "$args"
                            local arg_count=0
                            for val in "${VAL_LIST[@]}"; do
                                # Use sed to trim spaces while preserving quotes
                                val=$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

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
                                    if [[ "$val" =~ ^\"(.*)\"$ ]]; then
                                        # String Literal
                                        local content="${BASH_REMATCH[1]}"
                                        local label="str_arg_imp_${LINE_NO}_${arg_count}"
                                        emit_raw_data_fixed "$label db \`$content\`, 0"
                                        echo "    mov $target_reg, $label"
                                    elif [[ "$val" =~ ^-?[0-9]+$ ]]; then
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

                 elif [[ "$line" =~ ^([a-zA-Z0-9_]+)\[([a-zA-Z0-9_]+)\][[:space:]]*=[[:space:]]*(.*)$ ]]; then
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
                         elif [[ "$struct_name" == "str_eq" ]]; then
                             IFS=',' read -ra ADDR <<< "$args_str"
                             local arg1=$(echo "${ADDR[0]}" | xargs)
                             local arg2=$(echo "${ADDR[1]}" | xargs)
                             emit_str_eq "$arg1" "$arg2"
                             emit_variable_assign "$name" ""
                         elif [[ "$struct_name" == "str_get" ]]; then
                             IFS=',' read -ra ADDR <<< "$args_str"
                             local arg1=$(echo "${ADDR[0]}" | xargs)
                             local arg2=$(echo "${ADDR[1]}" | xargs)
                             emit_str_get "$arg1" "$arg2"
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
                             # Generic Function Call in Assignment
                             # Handle Arguments (Same as panggil but with string literal support)
                             if [[ -n "$args_str" ]]; then
                                 IFS=',' read -ra VAL_LIST <<< "$args_str"
                                 local arg_count=0
                                 for val in "${VAL_LIST[@]}"; do
                                     # Use sed to trim spaces while preserving quotes
                                     val=$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

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
                                         if [[ "$val" =~ ^\"(.*)\"$ ]]; then
                                             # String Literal
                                             local content="${BASH_REMATCH[1]}"
                                             local label="str_arg_${LINE_NO}_${arg_count}"
                                             emit_raw_data_fixed "$label db \`$content\`, 0"
                                             echo "    mov $target_reg, $label"
                                         elif [[ "$val" =~ ^-?[0-9]+$ ]]; then
                                             echo "    mov $target_reg, $val"
                                         else
                                             echo "    mov $target_reg, [var_$val]"
                                         fi
                                     fi
                                     ((arg_count++))
                                 done
                             fi
                             emit_call "$struct_name"
                             emit_variable_assign "$name" ""
                         fi
                    elif [[ "$expr" =~ ^([a-zA-Z0-9_]+)[[:space:]]*([-+*/%])[[:space:]]*([a-zA-Z0-9_]+)$ ]]; then
                         local op1="${BASH_REMATCH[1]}"
                         local op="${BASH_REMATCH[2]}"
                         local op2="${BASH_REMATCH[3]}"
                         emit_arithmetic_op "$op1" "$op" "$op2" "$name"
                    elif [[ "$expr" =~ ^([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)$ ]]; then
                         # Struct Field Access (RHS)
                         local struct_var="${BASH_REMATCH[1]}"
                         local field="${BASH_REMATCH[2]}"
                         local struct_type="${VAR_TYPE_MAP[$struct_var]}"

                         if [[ -n "$struct_type" ]]; then
                             local offset="${STRUCT_OFFSETS[${struct_type}_${field}]}"
                             if [[ -n "$offset" ]]; then
                                 emit_load_struct_field "$struct_var" "$offset"
                                 emit_variable_assign "$name" ""
                             else
                                 echo "; Error: Unknown field '$field' in struct '$struct_type'"
                             fi
                         else
                             echo "; Warning: Cannot resolve type for '$struct_var'. Assuming offset lookup fails."
                         fi
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
