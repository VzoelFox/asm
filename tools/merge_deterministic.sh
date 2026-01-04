#!/bin/bash
# Morph Deterministic Merge Algorithm
# Merge assembly fragments into cohesive shard with:
# 1. Section deduplication
# 2. Symbol table resolution
# 3. Deterministic ordering (sort by address/name)
# 4. Cross-platform compatibility

set -euo pipefail

# Configuration
MERGE_STRATEGY="${MERGE_STRATEGY:-smart}"  # simple, smart, ast

# Usage
if [ $# -lt 2 ]; then
    echo "Usage: $0 <output.asm> <fragment1.asm> [fragment2.asm ...]"
    echo ""
    echo "Merge assembly fragments deterministically"
    echo "MERGE_STRATEGY=simple|smart|ast (default: smart)"
    exit 1
fi

OUTPUT="$1"
shift
FRAGMENTS=("$@")

echo "[Merge] Strategy: $MERGE_STRATEGY"
echo "[Merge] Input fragments: ${#FRAGMENTS[@]}"
echo "[Merge] Output: $OUTPUT"

# Temporary files for processing
TMP_DIR="/tmp/morph_merge_$$"
mkdir -p "$TMP_DIR"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ================================================================
# Phase 1: Extract Sections from Each Fragment
# ================================================================

echo "[Phase 1] Extracting sections..."

for idx in "${!FRAGMENTS[@]}"; do
    frag="${FRAGMENTS[$idx]}"

    if [ ! -f "$frag" ] || [ ! -s "$frag" ]; then
        echo "[Phase 1] Skipping empty fragment: $frag"
        continue
    fi

    # Extract .data section
    sed -n '/^section \.data/,/^section /p' "$frag" | \
        grep -v "^section " > "$TMP_DIR/data_${idx}.asm" || true

    # Extract .bss section
    sed -n '/^section \.bss/,/^section /p' "$frag" | \
        grep -v "^section " > "$TMP_DIR/bss_${idx}.asm" || true

    # Extract .text section
    sed -n '/^section \.text/,/^section /p' "$frag" | \
        grep -v "^section " > "$TMP_DIR/text_${idx}.asm" || true

    # Extract function definitions (symbols)
    grep -E '^[a-z_][a-z0-9_]*:' "$frag" > "$TMP_DIR/symbols_${idx}.txt" || true
done

# ================================================================
# Phase 2: Deduplicate Sections (Deterministic)
# ================================================================

echo "[Phase 2] Deduplicating sections..."

# 2.1: Merge .data (deduplicate constants, sort by name)
{
    echo "    newline db 10, 0"
    echo "    ; --- Memory V2 Constants ---"
    cat "$TMP_DIR"/data_*.asm | grep -E '^\s+(HEAP_|PROT_|MAP_|SYS_)' | sort -u
    echo ""
    echo "    ; Error Messages"
    cat "$TMP_DIR"/data_*.asm | grep -E '^\s+msg_' | sort -u
    cat "$TMP_DIR"/data_*.asm | grep -E '^\s+len_' | sort -u
} > "$TMP_DIR/data_merged.asm"

# 2.2: Merge .bss (deduplicate variables, sort alphabetically for determinism)
{
    echo "    ; Heap Management"
    cat "$TMP_DIR"/bss_*.asm | grep -E '^\s+heap_' | sort -u
    echo "    ; Global Variables"
    cat "$TMP_DIR"/bss_*.asm | grep -E '^\s+var_global' | sort -u
    echo "    ; Swap Management"
    cat "$TMP_DIR"/bss_*.asm | grep -E '^\s+(snapshot_|sandbox_)' | sort -u
    echo "    ; User Variables"
    cat "$TMP_DIR"/bss_*.asm | grep -E '^\s+var_' | grep -v 'var_global' | sort -u
} > "$TMP_DIR/bss_merged.asm"

# 2.3: Merge .text (preserve order from fragments, deduplicate functions)
{
    # Runtime functions (from fragment 0 only, deterministic)
    if [ -f "$TMP_DIR/text_0.asm" ]; then
        sed -n '/^sys_/,/^[a-z_]/p' "$TMP_DIR/text_0.asm"
    fi

    echo ""
    echo "; === User Functions (Deterministic Order) ==="

    # Extract all user functions, sort by name (deterministic!)
    cat "$TMP_DIR"/symbols_*.txt | \
        grep -v "^_start:" | \
        grep -v "^sys_" | \
        sort -u | \
        while read -r symbol; do
            func_name="${symbol%:}"
            echo ""
            echo "; Function: $func_name"

            # Find first fragment containing this function
            for idx in "${!FRAGMENTS[@]}"; do
                if grep -q "^${func_name}:" "${FRAGMENTS[$idx]}" 2>/dev/null; then
                    # Extract function body
                    sed -n "/^${func_name}:/,/^[a-z_].*:/p" "${FRAGMENTS[$idx]}" | \
                        sed '$d'  # Remove last line (next function label)
                    break
                fi
            done
        done
} > "$TMP_DIR/text_merged.asm"

# ================================================================
# Phase 3: Build Final Shard (Deterministic Layout)
# ================================================================

echo "[Phase 3] Building final shard..."

{
    echo "default rel"
    echo ""
    echo "; ================================================================="
    echo "; Morph Compiled Shard (Deterministic Merge)"
    echo "; Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "; Fragments: ${#FRAGMENTS[@]}"
    echo "; Strategy: $MERGE_STRATEGY"
    echo "; ================================================================="
    echo ""

    # Section 1: .data
    echo "section .data"
    cat "$TMP_DIR/data_merged.asm"
    echo ""

    # Section 2: .text
    echo "section .text"
    echo "    global _start"
    echo ""

    # _start from first fragment only
    if [ -f "${FRAGMENTS[0]}" ]; then
        sed -n '/^_start:/,/^[a-z_][a-z0-9_]*:/p' "${FRAGMENTS[0]}" | sed '$d'
    fi

    # Merged user functions
    cat "$TMP_DIR/text_merged.asm"
    echo ""

    # Section 3: .bss
    echo "section .bss"
    cat "$TMP_DIR/bss_merged.asm"

} > "$OUTPUT"

# ================================================================
# Phase 4: Statistics & Validation
# ================================================================

output_lines=$(wc -l < "$OUTPUT")
unique_functions=$(grep -cE '^[a-z_][a-z0-9_]*:' "$OUTPUT" || echo 0)
unique_vars=$(grep -cE '^\s+var_' "$OUTPUT" || echo 0)

echo ""
echo "=== Merge Statistics ==="
echo "Output lines:      $output_lines"
echo "Unique functions:  $unique_functions"
echo "Unique variables:  $unique_vars"
echo "Merge strategy:    $MERGE_STRATEGY"
echo ""
echo "[Merge] ✓ Complete: $OUTPUT"
