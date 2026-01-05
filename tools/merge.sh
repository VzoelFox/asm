#!/bin/bash
# Morph Assembly Merger v2
# Properly handles duplicates

OUTPUT="build/morph_linked.asm"
MAIN="build/main.asm"

echo "=== Morph Assembly Merger v2 ==="

# Start fresh
> "$OUTPUT"

# 1. Header and data section
cat >> "$OUTPUT" << 'EOF'
default rel
section .data
    newline db 10, 0
    HEAP_CHUNK_SIZE equ 67108864
    PROT_READ       equ 0x1
    PROT_WRITE      equ 0x2
    MAP_PRIVATE     equ 0x02
    MAP_ANONYMOUS   equ 0x20
    SYS_MMAP        equ 9
    SYS_MUNMAP      equ 11
    SYS_OPEN        equ 2
    SYS_CLOSE       equ 3
    msg_oom db "Fatal: Out of Memory", 10, 0
    len_msg_oom equ $ - msg_oom
    msg_heap_fail db "Fatal: Heap Init Failed", 10, 0
    len_msg_heap_fail equ $ - msg_heap_fail

EOF

# 2. Collect unique string literals with unique names
echo "; === STRING LITERALS ===" >> "$OUTPUT"
counter=1000
for f in build/main.asm build/globals.asm build/constants.asm build/codegen.asm \
         build/types.asm build/supplier.asm \
         build/parser_helpers_*.asm build/parser_dispatch_*.asm \
         build/buffer.asm build/file_io.asm build/format.asm \
         build/hashmap.asm build/vector.asm build/string_utils.asm; do
    [ -f "$f" ] || continue
    # Extract string content and create unique labels
    grep -E '^\s+msg_[0-9]+ db "' "$f" | while read line; do
        content=$(echo "$line" | sed 's/.*db "\(.*\)", 0/\1/')
        echo "    msg_${counter} db \"$content\", 0" >> "$OUTPUT"
        echo "    len_msg_${counter} equ \$ - msg_${counter}" >> "$OUTPUT"
        ((counter++))
    done
done

# 3. Text section
cat >> "$OUTPUT" << 'EOF'

section .text
    global _start

_start:
    mov rbp, rsp
    mov rdi, [rsp]
    lea rsi, [rsp+8]
    push rdi
    push rsi
    call sys_init_heap
    pop rsi
    pop rdi
    mov [var_global_argc], rdi
    mov [var_global_argv], rsi
    call mulai
    mov rax, 60
    xor rdi, rdi
    syscall

EOF

# 4. Runtime functions (only from main.asm, once)
echo "; === RUNTIME ===" >> "$OUTPUT"
sed -n '/^sys_panic:/,/^mulai:/p' "$MAIN" | grep -v "^mulai:" >> "$OUTPUT"

# 5. User functions - extract carefully
echo "" >> "$OUTPUT"
echo "; === USER FUNCTIONS ===" >> "$OUTPUT"

declare -A seen_funcs

for f in build/main.asm build/globals.asm build/constants.asm build/codegen.asm \
         build/types.asm build/supplier.asm \
         build/parser_helpers_import.asm build/parser_helpers_struct.asm \
         build/parser_helpers_fungsi.asm build/parser_helpers_jika.asm \
         build/parser_helpers_loop.asm build/parser_helpers_stmt.asm \
         build/parser_dispatch_import.asm build/parser_dispatch_struct.asm \
         build/parser_dispatch_control.asm build/parser_dispatch_var_struct.asm \
         build/parser_dispatch_var_simple.asm build/parser_dispatch_cetak.asm \
         build/parser_dispatch_panggil.asm \
         build/buffer.asm build/file_io.asm build/format.asm \
         build/hashmap.asm build/vector.asm build/string_utils.asm; do
    
    [ -f "$f" ] || continue
    name=$(basename "$f" .asm)
    
    # Extract function blocks
    awk -v name="$name" '
    BEGIN { in_func = 0; skip = 0 }
    
    # Start of user function
    /^[a-zA-Z_][a-zA-Z0-9_]*:$/ {
        func_name = $0
        gsub(/:$/, "", func_name)
        
        # Skip runtime functions
        if (func_name ~ /^sys_/ || func_name ~ /^print_/ || func_name ~ /^_start/ || func_name ~ /^\.[a-z]/) {
            skip = 1
            next
        }
        skip = 0
        in_func = 1
        print "; --- " name ": " func_name " ---"
        print $0
        next
    }
    
    # End conditions
    /^section .bss/ { in_func = 0; skip = 0; next }
    /^section .data/ { in_func = 0; skip = 0; next }
    /^section .text/ { next }
    
    # Print function body
    in_func && !skip { print }
    
    ' "$f" >> "$OUTPUT"
done

# 6. BSS section
echo "" >> "$OUTPUT"
echo "section .bss" >> "$OUTPUT"
echo "    heap_start_ptr   resq 1" >> "$OUTPUT"
echo "    heap_current_ptr resq 1" >> "$OUTPUT"
echo "    heap_end_ptr     resq 1" >> "$OUTPUT"
echo "    var_global_argc  resq 1" >> "$OUTPUT"
echo "    var_global_argv  resq 1" >> "$OUTPUT"

# Collect unique variables
for f in build/*.asm; do
    grep -E "^\s+var_[a-zA-Z0-9_]+ resq" "$f" 2>/dev/null
done | sort -u | grep -v "var_global_argc\|var_global_argv" >> "$OUTPUT"

lines=$(wc -l < "$OUTPUT")
echo "Generated: $OUTPUT ($lines lines)"
