#!/bin/bash
# Morph Linker - Merge multiple .asm files into one executable
# Usage: ./tools/link.sh output.asm file1.asm file2.asm ...

OUTPUT="$1"
shift

if [ -z "$OUTPUT" ]; then
    echo "Usage: $0 output.asm file1.asm file2.asm ..."
    exit 1
fi

echo "; === MORPH LINKED OUTPUT ===" > "$OUTPUT"
echo "; Generated: $(date)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Extract runtime/boilerplate from first file (main.asm)
MAIN_ASM="$1"

# 1. Data section (only once)
echo "default rel" >> "$OUTPUT"
echo "section .data" >> "$OUTPUT"
sed -n '/^section .data$/,/^section .text$/p' "$MAIN_ASM" | grep -v "^section" >> "$OUTPUT"

# 2. Text section header
echo "" >> "$OUTPUT"
echo "section .text" >> "$OUTPUT"
echo "    global _start" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# 3. Extract _start and runtime from main
sed -n '/^_start:/,/^; --- Helper Functions ---$/p' "$MAIN_ASM" >> "$OUTPUT"

# 4. Extract all helper functions (sys_*, print_*, etc) from main
sed -n '/^; --- Helper Functions ---$/,/^section .bss$/p' "$MAIN_ASM" | grep -v "^section .bss" >> "$OUTPUT"

# 5. Extract user functions from ALL files
echo "" >> "$OUTPUT"
echo "; === USER FUNCTIONS ===" >> "$OUTPUT"

for f in "$@"; do
    name=$(basename "$f" .asm)
    echo "" >> "$OUTPUT"
    echo "; --- From: $name ---" >> "$OUTPUT"
    
    # Extract functions (after helper functions, before section .bss)
    # Look for function labels (name:) and their code
    awk '
    /^[a-zA-Z_][a-zA-Z0-9_]*:$/ && !/^_start:/ && !/^sys_/ && !/^print_/ && !/^\.[a-zA-Z]/ {
        in_func = 1
    }
    /^section .bss/ {
        in_func = 0
    }
    in_func {
        print
    }
    ' "$f" >> "$OUTPUT"
done

# 6. BSS section - collect all variables
echo "" >> "$OUTPUT"
echo "section .bss" >> "$OUTPUT"

# Standard runtime variables
echo "    heap_start_ptr   resq 1" >> "$OUTPUT"
echo "    heap_current_ptr resq 1" >> "$OUTPUT"
echo "    heap_end_ptr     resq 1" >> "$OUTPUT"
echo "    var_global_argc  resq 1" >> "$OUTPUT"
echo "    var_global_argv  resq 1" >> "$OUTPUT"

# Collect all var_ declarations from all files
for f in "$@"; do
    grep "var_.*resq" "$f" | grep -v "var_global_argc\|var_global_argv\|heap_" | sort -u >> "$OUTPUT"
done

# Remove duplicates
sort -u -o "$OUTPUT.tmp" <(grep "var_.*resq" "$OUTPUT")
# Keep non-var lines and add sorted vars
grep -v "var_.*resq" "$OUTPUT" > "$OUTPUT.tmp2"
cat "$OUTPUT.tmp2" "$OUTPUT.tmp" > "$OUTPUT"
rm -f "$OUTPUT.tmp" "$OUTPUT.tmp2"

echo "" >> "$OUTPUT"
echo "; === END ===" >> "$OUTPUT"

echo "Linked: $OUTPUT"
wc -l "$OUTPUT"
