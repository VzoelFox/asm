#!/bin/bash
# Quick ASM Checker - Lightweight debugger untuk N1 output
# Deteksi undefined symbols, stack issues, section problems

ASM_FILE="$1"

if [ -z "$ASM_FILE" ]; then
    echo "Usage: $0 <asm_file>"
    exit 1
fi

if [ ! -f "$ASM_FILE" ]; then
    echo "ERROR: File not found: $ASM_FILE"
    exit 1
fi

echo "========================================="
echo "  QUICK ASM CHECK - N1 Debugger"
echo "========================================="
echo "File: $ASM_FILE"
echo ""

# === 1. UNDEFINED SYMBOLS CHECK ===
echo "=== 1. Undefined Symbol Detection ==="

# Try to assemble dengan nasm
NASM_OUTPUT=$(nasm -felf64 "$ASM_FILE" 2>&1)
NASM_EXIT=$?

if [ $NASM_EXIT -eq 0 ]; then
    echo "✅ NASM assembly successful - No undefined symbols!"
else
    echo "🔴 NASM assembly failed"
    echo ""

    # Extract undefined symbols
    UNDEFINED=$(echo "$NASM_OUTPUT" | grep "error: symbol" | sed "s/.*symbol \`\([^']*\)'.*/\1/" | sort -u)
    UNDEFINED_COUNT=$(echo "$UNDEFINED" | wc -l)

    echo "Undefined symbols found: $UNDEFINED_COUNT"
    echo ""
    echo "Top 10 undefined symbols:"
    echo "$UNDEFINED" | head -10
    echo ""

    # Categorize by pattern
    VAR_COUNT=$(echo "$UNDEFINED" | grep "^var_" | wc -l)
    HEAP_COUNT=$(echo "$UNDEFINED" | grep "heap_" | wc -l)
    POOL_COUNT=$(echo "$UNDEFINED" | grep "POOL\|INITIALIZED\|ARENA" | wc -l)

    echo "Breakdown:"
    echo "  var_* symbols: $VAR_COUNT"
    echo "  heap_* symbols: $HEAP_COUNT"
    echo "  Pool/Arena symbols: $POOL_COUNT"
    echo ""

    # Diagnosis
    if [ $VAR_COUNT -gt 100 ]; then
        echo "🔴 DIAGNOSIS: Bootstrap compiler limitation"
        echo "   → No BSS section generation for cross-module globals"
        echo "   → Solution: Use N1 compiler or add BSS generation to bootstrap"
    fi

    if [ $POOL_COUNT -gt 0 ]; then
        echo "🔴 DIAGNOSIS: Memory pool globals not available"
        echo "   → POOLS_INITIALIZED, VECTOR_DATA_POOL, etc not in BSS"
        echo "   → Solution: Compile lib/memory_pool.fox first, link manually"
    fi
fi

echo ""

# === 2. STACK DEPTH ANALYSIS ===
echo "=== 2. Stack Depth Analysis ==="

PUSH_COUNT=$(grep -c "^\s*push" "$ASM_FILE")
POP_COUNT=$(grep -c "^\s*pop" "$ASM_FILE")
BALANCE=$((PUSH_COUNT - POP_COUNT))

echo "Push instructions: $PUSH_COUNT"
echo "Pop instructions: $POP_COUNT"
echo "Balance: $BALANCE"

if [ $BALANCE -gt 100 ]; then
    echo "🟡 WARNING: High push/pop imbalance ($BALANCE)"
    echo "   → Possible stack leak or deep recursion"
elif [ $BALANCE -lt -10 ]; then
    echo "🔴 ERROR: Negative balance ($BALANCE)"
    echo "   → Stack underflow detected!"
else
    echo "✅ Stack balance looks healthy"
fi

echo ""

# === 3. SECTION VERIFICATION ===
echo "=== 3. Section Verification ==="

HAS_DATA=$(grep -c "^section .data" "$ASM_FILE")
HAS_BSS=$(grep -c "^section .bss" "$ASM_FILE")
HAS_TEXT=$(grep -c "^section .text" "$ASM_FILE")

echo "Sections found:"
echo "  .data: $HAS_DATA"
echo "  .bss: $HAS_BSS"
echo "  .text: $HAS_TEXT"

if [ $HAS_BSS -eq 0 ]; then
    echo "🔴 CRITICAL: No .bss section!"
    echo "   → Global variables akan undefined"
    echo "   → Bootstrap compiler limitation confirmed"
fi

echo ""

# === 4. FUNCTION ANALYSIS ===
echo "=== 4. Function Analysis ==="

FUNC_COUNT=$(grep -c "^[a-z_][a-z0-9_]*:" "$ASM_FILE")
echo "Functions defined: $FUNC_COUNT"

# Detect potentially problematic functions
echo ""
echo "Checking for known problem functions:"

INIT_GLOBALS=$(grep -c "^init_globals:" "$ASM_FILE")
if [ $INIT_GLOBALS -gt 0 ]; then
    # Count instructions in init_globals
    INIT_START=$(grep -n "^init_globals:" "$ASM_FILE" | cut -d: -f1)
    INIT_END=$(tail -n +$INIT_START "$ASM_FILE" | grep -n "^[a-z_][a-z0-9_]*:" | head -2 | tail -1 | cut -d: -f1)

    if [ -n "$INIT_END" ]; then
        INIT_SIZE=$((INIT_END - INIT_START))
        echo "  init_globals: $INIT_SIZE lines"

        if [ $INIT_SIZE -gt 200 ]; then
            echo "  🔴 WARNING: init_globals too large ($INIT_SIZE lines)"
            echo "     → Known to cause stack overflow"
            echo "     → Solution: Split into smaller functions"
        fi
    fi
fi

echo ""

# === 5. SIZE STATISTICS ===
echo "=== 5. File Statistics ==="

TOTAL_LINES=$(wc -l < "$ASM_FILE")
FILE_SIZE=$(du -h "$ASM_FILE" | cut -f1)

echo "Total lines: $TOTAL_LINES"
echo "File size: $FILE_SIZE"

if [ $TOTAL_LINES -gt 50000 ]; then
    echo "🟡 WARNING: Very large assembly file"
    echo "   → May indicate over-inlining or code bloat"
fi

echo ""

# === SUMMARY ===
echo "========================================="
echo "  SUMMARY"
echo "========================================="

if [ $NASM_EXIT -eq 0 ]; then
    echo "✅ Assembly is valid - Ready to link"
    echo ""
    echo "Next steps:"
    echo "  ld $ASM_FILE.o -o executable"
else
    echo "🔴 Assembly has errors - Cannot link"
    echo ""
    echo "Recommended actions:"

    if [ $VAR_COUNT -gt 50 ]; then
        echo "  1. Fix cross-module globals (add BSS generation)"
        echo "  2. Or use N1 compiler instead of bootstrap"
    fi

    if [ $POOL_COUNT -gt 0 ]; then
        echo "  3. Compile memory_pool.fox separately"
        echo "  4. Link object files together"
    fi

    if [ $HAS_BSS -eq 0 ]; then
        echo "  5. CRITICAL: Add BSS section generation to codegen"
    fi
fi

echo ""
echo "========================================="
