#!/bin/bash
# Smart Fragment Splitter - Split at syntactic boundaries
# Ensures each fragment is self-contained compilation unit

set -euo pipefail

INPUT="$1"
OUTPUT_DIR="${2:-/tmp/morph_fragments}"
MAX_FRAGMENT_SIZE="${3:-150}"  # Soft limit (lines)

mkdir -p "$OUTPUT_DIR"

echo "[Smart Split] Input: $INPUT"
echo "[Smart Split] Max fragment size: $MAX_FRAGMENT_SIZE lines"

fragment_id=0
current_fragment="$OUTPUT_DIR/fragment_${fragment_id}.fox"
line_count=0
in_function=0
in_struct=0
brace_depth=0

# Track syntactic context
> "$current_fragment"

while IFS= read -r line; do
    # Write line to current fragment
    echo "$line" >> "$current_fragment"
    line_count=$((line_count + 1))

    # Track context
    case "$line" in
        *"fungsi "*)
            in_function=1
            ;;
        *"tutup_fungsi"*)
            in_function=0
            ;;
        *"struktur "*)
            in_struct=1
            ;;
        *"tutup_struktur"*)
            in_struct=0
            ;;
        *"jika "* | *"selama "*)
            brace_depth=$((brace_depth + 1))
            ;;
        *"tutup_jika"* | *"tutup_selama"*)
            brace_depth=$((brace_depth - 1))
            ;;
    esac

    # Check if we can split (at safe boundary)
    if [ $line_count -ge $MAX_FRAGMENT_SIZE ]; then
        # Only split if:
        # 1. Not inside function
        # 2. Not inside struct
        # 3. All blocks closed (brace_depth == 0)
        if [ $in_function -eq 0 ] && [ $in_struct -eq 0 ] && [ $brace_depth -eq 0 ]; then
            echo "[Fragment $fragment_id] $line_count lines (safe boundary found)"

            # Start new fragment
            fragment_id=$((fragment_id + 1))
            current_fragment="$OUTPUT_DIR/fragment_${fragment_id}.fox"
            > "$current_fragment"
            line_count=0
        fi
    fi
done < "$INPUT"

# Close last fragment
if [ $line_count -gt 0 ]; then
    echo "[Fragment $fragment_id] $line_count lines (EOF)"
fi

total_fragments=$((fragment_id + 1))
echo "[Smart Split] Created $total_fragments fragments"
echo "$total_fragments"  # Return count for caller
