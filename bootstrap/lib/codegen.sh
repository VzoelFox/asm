# Codegen: Generates Morph Bytecode (Binary)

init_codegen() {
    # File Header: V Z O E L F O XS (16 bytes)
    # Hex: 56 20 5A 20 4F 20 45 20 4C 20 46 20 4F 20 58 53
    # Use printf to create binary content

    # Define Opcode Constants
    OP_HALT=01
    OP_LOADI=02
    OP_ADD=03
    OP_SUB=04
    OP_SYS=05
    OP_MUL=09
    OP_DIV=0A
    OP_MOV=0B
    OP_DEBUG_PRINT_CHAR=AA
    OP_PRINT_INT=AB

    # Header
    printf "\x56\x20\x5A\x20\x4F\x20\x45\x20\x4C\x20\x46\x20\x4F\x20\x58\x53"
}

# Register Allocator State (Global Scope)
# R0-R9: Variables
# R10-R15: Scratch
VAR_COUNT=0
declare -A VAR_MAP

# Helper to output 4-byte instruction
emit_inst() {
    local op=$1
    local dest=$2
    local src1=$3
    local src2=$4

    # Default to 0 if missing
    [ -z "$dest" ] && dest=0
    [ -z "$src1" ] && src1=0
    [ -z "$src2" ] && src2=0

    # Use printf with correct escape sequence for binary output
    printf "\x$op\x$dest\x$src1\x$src2"
}

# --- Register Allocation Helpers ---
get_var_reg() {
    local name="$1"
    if [[ -z "${VAR_MAP[$name]}" ]]; then
        # Allocate new register
        local reg_idx=$VAR_COUNT
        VAR_MAP[$name]=$reg_idx
        ((VAR_COUNT++))
    fi
    echo "${VAR_MAP[$name]}" # Return decimal index (0-9)
}

to_hex() {
    printf "%02X" "$1"
}

# --- Features ---

emit_variable_decl() {
    local name="$1"
    # Just ensure it has a register mapped
    get_var_reg "$name" > /dev/null
}

emit_variable_assign() {
    local name="$1"
    local value="$2"

    local reg_idx=$(get_var_reg "$name")
    local reg_hex=$(to_hex "$reg_idx")

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        # Assign Immediate: LOADI REG, VAL
        # Note: LOADI only supports 8-bit immediate in Phase 1 VM! (0-255)
        # TODO: Support larger integers via multiple loads/shifts later.
        local val_hex=$(to_hex "$value")
        emit_inst "$OP_LOADI" "$reg_hex" "$val_hex" "00"
    elif [[ -n "$value" ]]; then
        # Assign from another variable?
        # Logic is simpler: if value is empty, it means "Assign RAX to Var" (result of expr)
        # If value is present, it's a number or var name.

        # Check if value is a variable name
        if [[ -n "${VAR_MAP[$value]}" ]]; then
            local src_reg=$(get_var_reg "$value")
            local src_hex=$(to_hex "$src_reg")
            # MOV DEST, SRC
            emit_inst "$OP_MOV" "$reg_hex" "$src_hex" "00"
        fi
    else
        # Assign result from calculation (Assume stored in R10 - Scratch Result)
        # We need a convention. Let's say expr result is always in R10 (0A).
        emit_inst "$OP_MOV" "$reg_hex" "0A" "00"
    fi
}

load_operand_to_reg() {
    local op="$1"
    local dest_reg_hex="$2"

    if [[ "$op" =~ ^[0-9]+$ ]]; then
        local val_hex=$(to_hex "$op")
        emit_inst "$OP_LOADI" "$dest_reg_hex" "$val_hex" "00"
    else
        local src_reg=$(get_var_reg "$op")
        local src_hex=$(to_hex "$src_reg")
        emit_inst "$OP_MOV" "$dest_reg_hex" "$src_hex" "00"
    fi
}

emit_arithmetic_op() {
    local num1="$1"
    local op="$2"
    local num2="$3"
    local store_to="$4"

    # Use R11 and R12 as temp source operands
    # Store result in R10

    load_operand_to_reg "$num1" "0B" # R11
    load_operand_to_reg "$num2" "0C" # R12

    local opcode=""
    if [ "$op" == "+" ]; then opcode="$OP_ADD";
    elif [ "$op" == "-" ]; then opcode="$OP_SUB";
    elif [ "$op" == "*" ]; then opcode="$OP_MUL";
    elif [ "$op" == "/" ]; then opcode="$OP_DIV"; fi

    # OP DEST(R10), SRC1(R11), SRC2(R12)
    emit_inst "$opcode" "0A" "0B" "0C"

    if [ -n "$store_to" ]; then
        emit_variable_assign "$store_to" ""
    else
        # Print result immediately (Implicitly R10)
        emit_print ""
    fi
}

emit_print() {
    local content="$1"

    if [[ "$content" =~ ^\" ]]; then
        # String Literal (Char by Char)
        content="${content%\"}"
        content="${content#\"}"

        for (( i=0; i<${#content}; i++ )); do
            char="${content:$i:1}"
            hex_val=$(printf "%x" "'$char")
            emit_inst "$OP_DEBUG_PRINT_CHAR" "00" "$hex_val" "00"
        done
        emit_inst "$OP_DEBUG_PRINT_CHAR" "00" "0A" "00" # Newline

    elif [[ "$content" =~ ^[0-9]+$ ]]; then
        # Print Immediate Integer
        # Load to R10, then print R10
        local val_hex=$(to_hex "$content")
        emit_inst "$OP_LOADI" "0A" "$val_hex" "00"
        emit_inst "$OP_PRINT_INT" "0A" "00" "00"

    elif [[ -n "$content" ]]; then
        # Print Variable
        local reg_idx=$(get_var_reg "$content")
        local reg_hex=$(to_hex "$reg_idx")
        emit_inst "$OP_PRINT_INT" "$reg_hex" "00" "00"
    else
        # Implicit Print (Result in R10)
        emit_inst "$OP_PRINT_INT" "0A" "00" "00"
    fi
}

emit_exit() {
    emit_inst "$OP_HALT" "00" "00" "00"
}

# --- STUBBED (Flow Control) ---
emit_if_start() { :; }
emit_if_end() { :; }
emit_loop_start() { :; }
emit_loop_end() { :; }
emit_function_start() { :; }
emit_function_end() { :; }
emit_call() { :; }
emit_snapshot() { :; }
emit_restore() { :; }
emit_raw_asm() { :; }
emit_raw_data_fixed() { :; }

emit_output() {
    :
}
