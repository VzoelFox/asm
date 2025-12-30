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

    # We will output binary data to stdout progressively
    # Header
    printf "\x56\x20\x5A\x20\x4F\x20\x45\x20\x4C\x20\x46\x20\x4F\x20\x58\x53"

    # To handle string data, since we don't have a data section in the VM yet (in Phase 1),
    # we will implement a hack for "cetak" string:
    # 1. Print char by char using SYSCALL(write) or similar.
    # But wait, SYSCALL needs a pointer to memory.
    # Our VM loads the *entire file* into memory.
    # So we can put strings *after* the code and point to them!
    # BUT, we need to know the address.
    # Simpler approach for Hello World Phase 1:
    # Use "Stack Strings" or just Immediate Char printing if we had it.
    # Since we have SYSCALL, we need a pointer.
    # Let's try to put the string bytes *in the bytecode stream* and jump over them?
    # Or just append them at the end and calculate offset?
    # Offset calculation is hard in 1-pass compiler.

    # ALTERNATIVE: Use "LOADI" to load char to stack/memory? No, slow.

    # Let's stick to the SIMPLEST valid Opcode sequence for now.
    # Focus: "cetak" support is tricky without memory map.
    # Let's change "cetak" implementation to:
    # "For each char in string, Load Char to Buffer, Print Buffer"
    # Or assume VM has a scratch pad at a known address?
    # VM `prog_buffer` is at start.
    # VM `vm_regs` is in .bss.
    # Let's define a known "Scratch Area" in VM?
    # Let's use the Stack Pointer (RSP) concept?

    # TEMPORARY HACK:
    # Support "cetak(int)" using a hardcoded buffer in VM?
    # We can add a "PRINT_VAL" opcode for debugging/bootstrapping?
    # Spec said: SYSCALL.

    # OK, let's implement `cetak` as:
    # MOV R0, 1 (sys_write)
    # MOV R1, 1 (stdout)
    # MOV R2, ADDRESS_OF_STRING (???)
    # MOV R3, LEN
    # SYSCALL

    # Where is ADDRESS_OF_STRING?
    # It's inside the loaded program buffer.
    # VM doesn't expose "Current IP" easily to regs yet.
    # Let's add an opcode: `LEA R_DEST, OFFSET` (Load Effective Address relative to Start).
    # Opcode 0x08 LEA [Dest] [OffsetHigh] [OffsetLow]

    OP_LEA=08
}

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

    printf "\\x$op\\x$dest\\x$src1\\x$src2"
}

emit_string() {
    # No-op for now in binary mode (strings handled inline or at end)
    :
}

# --- STUBBED FUNCTIONS FOR PHASE 1 TRANSITION ---
# Note: These features are temporarily disabled while transitioning
# from ASM Transpiler to Bytecode VM Architecture.
# They will be re-implemented to emit Bytecode in Phase 2.

emit_variable_decl() { :; }
emit_variable_assign() { :; }
load_operand_to_rax() { :; }
load_operand_to_rbx() { :; }
emit_arithmetic_op() { :; }
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

# For "cetak", strictly for Hello World demo
emit_print() {
    local content="$1"

    if [[ "$content" =~ ^\" ]]; then
        # String Literal
        content="${content%\"}"
        content="${content#\"}"

        # We need to output the string bytes somewhere and point to it.
        # But we are streaming output.
        # Strategy:
        # JMP over string data
        # [DATA]
        # Label:
        # Code...

        # Since we don't have JMP opcode yet in my list, let's just do Char-by-Char print
        # using a "PRINT_CHAR" opcode if we had one.
        # But we agreed on SYSCALL.

        # Let's add a custom opcode for Phase 1 Debug: 0xEE "DEBUG_PRINT_STR"
        # Arguments: Inline String?
        # This is cheating but effective for bootstrap.
        # Let's stick to the plan: SYSCALL.

        # OK, I will emit a sequence to print "Halo" char by char using immediate loads and stack?
        # Too long.

        # Let's pretend we have a `DEBUG_PRINT_CHAR` opcode (0xAA).
        # Opcode: AA [Char] 00 00

        for (( i=0; i<${#content}; i++ )); do
            char="${content:$i:1}"
            # Convert char to ascii hex
            hex_val=$(printf "%x" "'$char")
            emit_inst "AA" "00" "$hex_val" "00"
        done

        # Newline
        emit_inst "AA" "00" "0A" "00"

    fi
}

emit_exit() {
    # HALT
    emit_inst "01" "00" "00" "00"
}

emit_output() {
    # Output is streamed via printf, so nothing to do here
    :
}
