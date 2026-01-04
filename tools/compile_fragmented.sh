#!/bin/bash
# Morph Fragmented Compiler - Batch compilation using sandbox isolation
# Strategy: Split large files into fragments, compile separately, merge deterministically

set -euo pipefail

# Configuration
BATCH_SIZE=100          # Lines per fragment
MAX_FRAGMENTS=8         # Max sandboxes available
FRAGMENT_DIR="/tmp/morph_fragments_$$"
OUTPUT_DIR="/tmp/morph_output_$$"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Cleanup on exit
cleanup() {
    if [ -d "$FRAGMENT_DIR" ]; then
        rm -rf "$FRAGMENT_DIR"
    fi
    if [ -d "$OUTPUT_DIR" ]; then
        rm -rf "$OUTPUT_DIR"
    fi
}
trap cleanup EXIT

# Usage check
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.fox> [output.asm]"
    echo ""
    echo "Compile large Fox files using fragmented batch compilation"
    echo "Fragments are compiled in isolated sandboxes and merged deterministically"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-output_fragmented.asm}"

if [ ! -f "$INPUT_FILE" ]; then
    log_error "Input file not found: $INPUT_FILE"
    exit 1
fi

# Create working directories
mkdir -p "$FRAGMENT_DIR"
mkdir -p "$OUTPUT_DIR"

log_info "Fragmented compilation started"
log_info "Input: $INPUT_FILE"
log_info "Fragment size: $BATCH_SIZE lines"
log_info "Max sandboxes: $MAX_FRAGMENTS"

# Step 1: Analyze input file
total_lines=$(wc -l < "$INPUT_FILE")
num_batches=$(( (total_lines + BATCH_SIZE - 1) / BATCH_SIZE ))

log_info "Total lines: $total_lines"
log_info "Required batches: $num_batches"

if [ $num_batches -gt $MAX_FRAGMENTS ]; then
    log_warn "File needs $num_batches batches, but only $MAX_FRAGMENTS sandboxes available"
    log_warn "Will process in multiple rounds (TODO: implement multi-round)"
    num_batches=$MAX_FRAGMENTS
fi

# Step 2: Split into fragments
log_info "Splitting file into $num_batches fragments..."

fragment_id=0
declare -a fragment_files
declare -a fragment_asms
compiled_count=0

while [ $fragment_id -lt $num_batches ]; do
    start_line=$(( fragment_id * BATCH_SIZE + 1 ))
    end_line=$(( (fragment_id + 1) * BATCH_SIZE ))

    # Clamp to total lines
    if [ $end_line -gt $total_lines ]; then
        end_line=$total_lines
    fi

    fragment_file="$FRAGMENT_DIR/fragment_${fragment_id}.fox"
    fragment_asm="$OUTPUT_DIR/fragment_${fragment_id}.asm"

    # Extract fragment with line preservation
    sed -n "${start_line},${end_line}p" "$INPUT_FILE" > "$fragment_file"

    fragment_files[$fragment_id]="$fragment_file"

    log_info "[Sandbox $fragment_id] Lines $start_line-$end_line → $fragment_file"

    fragment_id=$(( fragment_id + 1 ))

    # Break if we've covered all lines
    if [ $end_line -ge $total_lines ]; then
        break
    fi
done

# Step 3: Compile each fragment (isolated sandboxes)
log_info "Compiling fragments in isolated sandboxes..."

for idx in "${!fragment_files[@]}"; do
    frag_file="${fragment_files[$idx]}"
    frag_asm="$OUTPUT_DIR/fragment_${idx}.asm"

    log_info "[Sandbox $idx] Compiling $(basename "$frag_file")..."

    # Compile with timeout per fragment (not total!)
    if timeout 30s ./bootstrap/morph.sh "$frag_file" > "$frag_asm" 2>&1; then
        asm_lines=$(wc -l < "$frag_asm")
        log_info "[Sandbox $idx] ✓ Compiled ($asm_lines lines assembly)"
        fragment_asms[$idx]="$frag_asm"
        compiled_count=$(( compiled_count + 1 ))
    else
        log_error "[Sandbox $idx] ✗ Compilation failed or timeout"
        # Create empty placeholder
        touch "$frag_asm"
        fragment_asms[$idx]=""
    fi
done

log_info "Compiled $compiled_count / ${#fragment_files[@]} fragments successfully"

# Step 4: Merge fragments → shard
if [ $compiled_count -eq 0 ]; then
    log_error "No fragments compiled successfully, aborting"
    exit 1
fi

log_info "Merging fragments into shard: $OUTPUT_FILE"

# For now, simple concatenation (Phase 2: smart merge with deduplication)
{
    echo "default rel"
    echo ""
    echo "; === MERGED FROM $compiled_count FRAGMENTS ==="
    echo "; Source: $INPUT_FILE ($total_lines lines)"
    echo "; Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""

    # Include first fragment's full header (runtime, memory, etc.)
    if [ -n "${fragment_asms[0]}" ]; then
        cat "${fragment_asms[0]}"
    fi

    # Append other fragments' unique code (TODO: deduplicate in Phase C)
    for idx in $(seq 1 $(( ${#fragment_asms[@]} - 1 )) ); do
        if [ -n "${fragment_asms[$idx]}" ]; then
            echo ""
            echo "; === Fragment $idx ==="
            # Skip headers, only include functions
            sed -n '/^[a-z_][a-z0-9_]*:/,/^section /p' "${fragment_asms[$idx]}"
        fi
    done
} > "$OUTPUT_FILE"

output_size=$(wc -l < "$OUTPUT_FILE")
log_info "✓ Merge complete: $OUTPUT_FILE ($output_size lines)"

# Step 5: Summary statistics
echo ""
echo "=== Compilation Summary ==="
echo "Input:             $INPUT_FILE ($total_lines lines)"
echo "Fragments:         $compiled_count / ${#fragment_files[@]}"
echo "Output:            $OUTPUT_FILE ($output_size lines)"
echo "Fragment size:     $BATCH_SIZE lines"
echo "Sandboxes used:    ${#fragment_files[@]} / $MAX_FRAGMENTS"
echo ""
log_info "Fragmented compilation complete!"
