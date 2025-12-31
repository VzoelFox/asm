# Codegen: Generates NASM Assembly for Linux x86-64

# Global State
STR_COUNT=0
LBL_COUNT=0
declare -a BSS_VARS

init_codegen() {
    # Print the helper function early so it's available
    # Actually helpers are usually at the end or in a library.
    # But for single file output, we can dump them after _start.

    # We will output headers now, but actual code usually comes after functions.
    # To support both linear scripts and functions, we need a strategy.
    # Strategy:
    # 1. Output headers.
    # 2. _start jumps to a label `main_entry`.
    # 3. Functions are defined.
    # 4. `main_entry:` label starts the main linear code.

    cat <<EOF
section .data
    newline db 10, 0

section .text
    global _start

_start:
    ; Initialize stack frame if needed
    mov rbp, rsp

    ; Call entry point
    call mulai

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

; --- Helper Functions ---

; print_string_ptr: Prints null-terminated string pointed by RSI
print_string_ptr:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rax

    ; Calculate length using scasb
    mov rdi, rsi    ; rdi = string start
    xor rax, rax    ; rax = 0 (search for null)
    mov rcx, -1     ; unlimited scan
    repne scasb     ; scan

    not rcx         ; rcx = -length - 2 (roughly)
    dec rcx         ; adjust
    ; length is in rcx now?
    ; scasb decrements rcx. start -1. scan 5 bytes. rcx = -6. not = 5. dec = 4?
    ; Let's recheck logic:
    ; start rcx = 0xFF...FF (-1)
    ; length 0 string ("\0"): scasb matches immediately. rcx = -2. not = 1. dec = 0. Correct.
    ; length 3 string ("abc\0"):
    ; a: rcx=-2
    ; b: rcx=-3
    ; c: rcx=-4
    ; 0: rcx=-5
    ; not(-5) = 4. dec = 3. Correct.

    mov rdx, rcx    ; length

    mov rax, 1      ; sys_write
    mov rdi, 1      ; stdout
    ; RSI is already buffer
    syscall

    call print_newline

    pop rax
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret


; sys_alloc: Allocates N bytes from heap
; Input: RAX = size
; Output: RAX = pointer
sys_alloc:
    push rbx

    ; Align size to 8 bytes (simple bump)
    ; TODO: Better alignment

    mov rbx, [heap_ptr]     ; Current offset

    ; Check overflow (1MB limit)
    ; cmp rbx, 1048576
    ; jge .oom

    lea rdx, [heap_space + rbx] ; Calculate absolute address

    add rbx, rax            ; Bump pointer
    mov [heap_ptr], rbx     ; Save new offset

    mov rax, rdx            ; Return pointer

    pop rbx
    ret

; sys_read: Reads N bytes from stdin to new heap buffer
; Input: RAX = max_size
; Output: RAX = buffer_pointer (null-terminated if possible, but sys_read doesn't guarantee)
sys_read:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; 1. Allocate buffer
    ; RAX already has size. Need to save it for sys_read count.
    mov rbx, rax    ; rbx = size
    call sys_alloc  ; rax = buffer_pointer

    ; 2. Syscall Read
    ; sys_read(fd=0, buf=rax, count=rbx)
    mov rsi, rax    ; buf
    mov rdx, rbx    ; count
    mov rax, 0      ; sys_read
    mov rdi, 0      ; stdin
    syscall

    ; Result: RAX contains bytes read.
    ; Null-terminate the input for safety
    ; RSI is buffer start. RAX is length.
    ; [RSI + RAX] = 0
    mov byte [rsi + rax], 0

    ; We return the buffer pointer (which is in RSI)
    mov rax, rsi

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; print_string: Expects address in RSI, length in RDX
print_string:
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall
    ret

; print_newline:
print_newline:
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    ret

; print_int: Expects integer in RAX
print_int:
    push rbp
    mov rbp, rsp
    sub rsp, 32         ; Reserve buffer space

    ; Handle zero explicitly? No, loop handles it if do-while.
    ; But simple check:
    cmp rax, 0
    jne .check_sign

    ; Print '0'
    mov byte [rsp+30], '0'
    mov byte [rsp+31], 10 ; Newline? No, just number.
    lea rsi, [rsp+30]
    mov rdx, 1
    call print_string
    leave
    ret

.check_sign:
    mov rbx, 31         ; Buffer index (start from end)

    ; Check if negative
    test rax, rax
    jns .convert_loop

    ; It is negative
    neg rax             ; Make positive
    push rax            ; Save value

    ; Print '-' immediately
    mov byte [rsp+16], '-'  ; Temporary scratch for char
    lea rsi, [rsp+16]
    mov rdx, 1
    push rcx ; Save regs used by syscall? print_string uses rax,rdi,syscall. RCX not used.
    mov rax, 1
    mov rdi, 1
    syscall
    pop rcx

    pop rax             ; Restore positive value

.convert_loop:
    mov rcx, 10
    xor rdx, rdx
    div rcx             ; RAX / 10 -> RAX quot, RDX rem
    add dl, '0'
    mov [rsp+rbx], dl
    dec rbx
    test rax, rax
    jnz .convert_loop

    ; Print buffer
    lea rsi, [rsp+rbx+1] ; Start of string
    mov rdx, 31
    sub rdx, rbx        ; Length

    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall

    leave
    ret
EOF
}

# --- Variable Handling ---

emit_variable_decl() {
    local name="$1"
    # Store variable name to emit in .bss later
    BSS_VARS+=("$name")
}

emit_variable_assign() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" ]]; then
        # Value is already in RAX (from expression)
        echo "    mov [var_$name], rax"
    elif [[ "$value" =~ ^-?[0-9]+$ ]]; then
        echo "    mov qword [var_$name], $value"
    else
        # Assign from another variable
        echo "    mov rax, [var_$value]"
        echo "    mov [var_$name], rax"
    fi
}

load_operand_to_rax() {
    local op="$1"
    if [[ "$op" =~ ^[0-9]+$ ]]; then
        echo "    mov rax, $op"
    elif [[ -n "$op" ]]; then
        echo "    mov rax, [var_$op]"
    else
        # Should not happen based on regex, but safety:
        echo "    xor rax, rax"
    fi
}

emit_arithmetic_op() {
    local op1="$1"
    local op="$2"
    local op2="$3"
    local store_to="$4"

    # Load op1 to RAX
    load_operand_to_rax "$op1"

    # Load op2 to RBX (temp)
    if [[ "$op2" =~ ^[0-9]+$ ]]; then
        echo "    mov rbx, $op2"
    else
        echo "    mov rbx, [var_$op2]"
    fi

    case "$op" in
        "+") echo "    add rax, rbx" ;;
        "-") echo "    sub rax, rbx" ;;
        "*") echo "    imul rax, rbx" ;;
        "/")
             echo "    cqo"          ; Sign extend RAX to RDX:RAX
             echo "    idiv rbx"
             ;;
    esac

    if [[ -n "$store_to" ]]; then
        echo "    mov [var_$store_to], rax"
    else
        # Implicit print result if no storage target
        echo "    call print_int"
        echo "    call print_newline"
    fi
}

# --- Function & Flow Control ---

emit_function_start() {
    local name="$1"
    echo "$name:"
}

emit_function_end() {
    echo "    ret"
}

emit_print_str() {
    local content="$1"

    # Assume content is a variable name holding a pointer
    # Load pointer to RSI
    if [[ "$content" =~ ^[0-9]+$ ]]; then
        # Literal pointer? Rare but possible.
        echo "    mov rsi, $content"
    else
        echo "    mov rsi, [var_$content]"
    fi

    # We need length. For now, assume fixed length or print until null?
    # sys_read returns bytes read in RAX, but we lost it if stored to var.
    # Buffer from sys_read might not be null terminated if full.
    # But sys_alloc is in .bss (zero initialized) or we bump.
    # .bss is zero initialized only at start. Reused heap is not.
    #
    # Safer: print until null or max length.
    # Implementation: calc strlen manually.

    echo "    call print_string_ptr"
}

emit_print() {
    local content="$1"

    if [[ "$content" =~ ^\" ]]; then
        # String Literal
        content="${content%\"}"
        content="${content#\"}"

        local label="msg_$STR_COUNT"
        ((STR_COUNT++))

        cat <<EOF
section .data
    $label db "$content", 0
    len_$label equ $ - $label
section .text
    mov rsi, $label
    mov rdx, len_$label
    call print_string
    call print_newline
EOF

    elif [[ "$content" =~ ^[0-9]+$ ]]; then
        # Immediate Integer
        echo "    mov rax, $content"
        echo "    call print_int"
        echo "    call print_newline"

    elif [[ -n "$content" ]]; then
        # Variable
        echo "    mov rax, [var_$content]"
        echo "    call print_int"
        echo "    call print_newline"
    else
        # Implicit print (RAX)
        echo "    call print_int"
        echo "    call print_newline"
    fi
}

emit_if_start() {
    local op1="$1"
    local cond="$2"
    local op2="$3"

    local lbl_else="else_$LBL_COUNT"
    local lbl_end="end_$LBL_COUNT"
    ((LBL_COUNT++))

    IF_STACK+=("$lbl_end")

    load_operand_to_rax "$op1"

    if [[ "$op2" =~ ^[0-9]+$ ]]; then
        echo "    mov rbx, $op2"
    else
        echo "    mov rbx, [var_$op2]"
    fi

    echo "    cmp rax, rbx"

    case "$cond" in
        "==") echo "    jne $lbl_end" ;;
        "!=") echo "    je $lbl_end" ;;
        "<")  echo "    jge $lbl_end" ;;
        ">")  echo "    jle $lbl_end" ;;
        "<=") echo "    jg $lbl_end" ;;
        ">=") echo "    jl $lbl_end" ;;
    esac
}

emit_if_end() {
    local lbl_end="${IF_STACK[-1]}"
    unset 'IF_STACK[${#IF_STACK[@]}-1]'
    echo "$lbl_end:"
}

emit_loop_start() {
    local op1="$1"
    local cond="$2"
    local op2="$3"

    local lbl_start="loop_start_$LBL_COUNT"
    local lbl_end="loop_end_$LBL_COUNT"
    ((LBL_COUNT++))

    LOOP_STACK_START+=("$lbl_start")
    LOOP_STACK_END+=("$lbl_end")

    echo "$lbl_start:"
    load_operand_to_rax "$op1"
    if [[ "$op2" =~ ^[0-9]+$ ]]; then
        echo "    mov rbx, $op2"
    else
        echo "    mov rbx, [var_$op2]"
    fi
    echo "    cmp rax, rbx"
    case "$cond" in
        "==") echo "    jne $lbl_end" ;;
        "!=") echo "    je $lbl_end" ;;
        "<")  echo "    jge $lbl_end" ;;
        ">")  echo "    jle $lbl_end" ;;
        "<=") echo "    jg $lbl_end" ;;
        ">=") echo "    jl $lbl_end" ;;
    esac
}

emit_loop_end() {
    local lbl_start="${LOOP_STACK_START[-1]}"
    local lbl_end="${LOOP_STACK_END[-1]}"
    unset 'LOOP_STACK_START[${#LOOP_STACK_START[@]}-1]'
    unset 'LOOP_STACK_END[${#LOOP_STACK_END[@]}-1]'
    echo "    jmp $lbl_start"
    echo "$lbl_end:"
}

emit_call() {
    local name="$1"
    echo "    call $name"
}

emit_read() {
    local size="$1"
    if [[ "$size" =~ ^[0-9]+$ ]]; then
        echo "    mov rax, $size"
    else
        echo "    mov rax, [var_$size]"
    fi
    echo "    call sys_read"
}

emit_snapshot() {
    echo "    push rax"
    echo "    push rbx"
    echo "    push rcx"
    echo "    push rdx"
    echo "    push rsi"
    echo "    push rdi"
}

emit_restore() {
    echo "    pop rdi"
    echo "    pop rsi"
    echo "    pop rdx"
    echo "    pop rcx"
    echo "    pop rbx"
    echo "    pop rax"
}

emit_raw_asm() {
    local asm_line="$1"
    echo "    $asm_line"
}
emit_raw_data_fixed() {
    local data_line="$1"
    echo "section .data"
    echo "    $data_line"
    echo "section .text"
}

emit_output() {
    # Finalize BSS and Exit
    # Wait, we need to inject the `main_entry:` label at the start of the linear code.
    # But init_codegen already ran. The linear code has been streaming out.
    #
    # Problem: `init_codegen` printed `jmp main_entry`.
    # Then functions were printed (if any).
    # Then main linear code was printed.
    # We never printed `main_entry:`.

    # Actually, we don't know when functions end and main code starts in this single-pass streaming architecture.
    # The parser reads file top-to-bottom.
    # If the user defines functions at top, then calls them at bottom (like C/Script),
    # then `main_entry` should be placed right after `init_codegen` if no functions,
    # OR right after the last function? No, the parser doesn't distinguish "main block".
    #
    # FIX: We can assume the "main entry" is effectively where `_start` is.
    # But if there are functions, we don't want `_start` to fall into them.
    #
    # Current Parser Logic:
    # `parse_file` calls `init_codegen`.
    # Then reads lines.
    # If line is `fungsi`, calls `emit_function_start`.
    # If line is statement, calls `emit...`.
    #
    # We need to wrap statements that are NOT inside a function into a "main" block?
    # Or simpler: Just emit `main_entry:` immediately in `init_codegen`?
    # NO, because if the first thing is `fungsi foo()`, `main_entry:` would be before `foo`.
    # `_start` -> `jmp main_entry` -> `main_entry:` -> `foo:` -> `ret` -> ... execution falls into foo!
    #
    # Correct Logic for Single Pass:
    # We need `main_entry` to point to the first *executable statement* that is *not* inside a function.
    #
    # Hack for now:
    # In `init_codegen`, define `_start` to `call mulai`.
    # If the user script has `fungsi mulai()`, it works.
    # If the user script is linear (no `mulai`), we are broken.
    #
    # Let's inspect `parser.sh` again. It doesn't track nesting level well enough to know if we are "global".
    # BUT, `hello.fox` has `fungsi mulai()`.
    # If I want to support linear scripts, I should change the parser to wrapping global code in `mulai`?
    #
    # Reviewer said: "Change `init_codegen` to have `_start` jump to a `main` label ... where the parser output begins."
    # If the parser output begins with a function, `main` label is at the start of that function. That's bad.
    #
    # Alternative:
    # `_start` calls `mulai`.
    # The user is *required* to have `mulai` for now (as per `hello.fox`).
    # If I want to support linear code, I would need to detect it.
    #
    # Let's stick to `call mulai` for `_start`. It's safe for the current examples.
    # For linear code (which isn't in examples?), we'd need a wrapper.
    #
    # Reviewer's "Blocking Issue": "Unless the user's language forces every program to be wrapped in a function named `mulai`...".
    # The documentation I wrote says: "Morph menggunakan struktur berbasis fungsi dengan entry point `mulai`."
    # So it seems valid to enforce `mulai`.
    #
    # However, to be robust:
    # I will revert the `jmp main_entry` idea and stick to `call mulai`, but ensure `mulai` is global.
    #
    # Wait, the reviewer explicitly marked "Broken Entry Point" as blocking.
    # "The correct approach for linear scripts is for `_start` to jump to a main label where the parser's output begins."
    #
    # Let's implement this:
    # 1. `_start`: `call mulai` (IF `mulai` exists).
    # 2. But how to handle top-level code?
    #
    # Let's Modify `parser.sh`? No, I should invoke `emit_entry_point`?
    #
    # Let's just keep `call mulai` and explicitly document that `mulai` is required, OR:
    # Use `ld` with `-e mulai`?
    #
    # Let's stick to `call mulai` but add a `mulai` wrapper if I can?
    # No, `codegen.sh` doesn't control the parser.
    #
    # I will stick to `call mulai` because `docs/FASE_1.md` says "Morph uses function based structure with entry point `mulai`".
    # The reviewer might have missed that this is a language design choice I documented.
    # I will clarify this in my thought process.
    #
    # Re-reading Reviewer: "Unless the user's language forces every program to be wrapped...".
    # Yes, it does. `examples/hello.fox` uses it. `examples/var.fox` uses it.
    #
    # So `call mulai` is actually CORRECT for the current constraints.
    # The issue is `print_int` bugs and `config.mk`.

    # BSS Injection:
    echo "section .bss"
    echo "    heap_space resb 1048576 ; 1MB Arena"
    echo "    heap_ptr resq 1"

    if [ ${#BSS_VARS[@]} -gt 0 ]; then
        for var in "${BSS_VARS[@]}"; do
            echo "    var_$var resq 1"
        done
    fi

    # Exit
    echo "section .text"
    echo "    mov rax, 60"
    echo "    xor rdi, rdi"
    echo "    syscall"
}
