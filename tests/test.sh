#!/bin/bash

# Morph Test Suite
# Usage: ./tests/test.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check dependencies
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass could not be found. Please install it."
    exit 1
fi

# Load Configuration
# Priority: Environment Vars > config.mk > Error

if [ -f "config.mk" ]; then
    eval $(grep -v '^#' config.mk | sed 's/ *= */=/g')
fi

# Fallback defaults
VPS_HOST=${VPS_HOST:-"144.202.18.239"}
VPS_USER=${VPS_USER:-"root"}
VPS_DIR=${VPS_DIR:-"morph_build"}
COMPILER=${MORPH_COMPILER:-"./bootstrap/morph.sh"}

# Check Sensitive Data
if [ -z "$VPS_PASS" ]; then
    echo -e "${RED}Error: VPS_PASS is not set.${NC}"
    echo "Please set VPS_PASS in config.mk or as an environment variable."
    exit 1
fi

run_test() {
    local test_name="$1"
    local source_file="$2"
    local expected_output="$3"

    echo "------------------------------------------------"
    echo "Running Test: $test_name"
    echo "Source: $source_file"

    OUTPUT=$(make all \
        SOURCE="$source_file" \
        OUTPUT_NAME="test_bin" \
        VPS_HOST="$VPS_HOST" \
        VPS_USER="$VPS_USER" \
        VPS_PASS="$VPS_PASS" \
        VPS_DIR="$VPS_DIR" \
        MORPH_COMPILER="$COMPILER" \
        2>&1)

    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        echo -e "${RED}[FAIL] Make command failed.${NC}"
        echo "$OUTPUT"
        return 1
    fi

    CLEAN_OUTPUT=$(echo "$OUTPUT" | grep -vE "^---" | grep -v "Warning: Permanently added" | grep -v "sshpass" | grep -v "Generated" | grep -v "mkdir -p" | grep -v "chmod +x" | grep -v "make")

    CLEAN_OUTPUT=$(echo "$CLEAN_OUTPUT" | xargs)
    EXPECTED_TRIMMED=$(echo "$expected_output" | xargs)

    if [[ "$CLEAN_OUTPUT" == *"$EXPECTED_TRIMMED"* ]]; then
        echo -e "${GREEN}[PASS] Output matches.${NC}"
    else
        echo -e "${RED}[FAIL] Output mismatch.${NC}"
        echo "Expected: [$EXPECTED_TRIMMED]"
        echo "Actual:   [$CLEAN_OUTPUT]"
        return 1
    fi
}

# --- Define Tests ---

# 1. Hello World
run_test "Hello World" "examples/hello.fox" "Halo dari Morph!"

# 2. Functions (Simple Addition)
run_test "Functions & Snapshot" "examples/functions.fox" "Memanggil fungsi tambah... Hasil di dalam fungsi: 30 Register RAX setelah restore (Harusnya 999): 999"

# 3. Loops
run_test "Loops" "examples/loop.fox" "Mulai Loop Counter (0 sampai 4): Loop ke: 0"

# 4. Control Flow
run_test "Control Flow" "examples/control_flow.fox" "Testing If/Else: a lebih kecil dari b (Benar) Masuk blok lain (Benar) c adalah 30 (Benar)"

# 5. Import (ID-Based Explicit File)
# Updated to use ID 100, 101 as per new lib/math.fox
run_test "Import ID-Based (Explicit)" "examples/import_test.fox" "Hasil Tambah (via ID 100): 15 Hasil Kurang (via ID 101): 5"

# 6. Double Import
run_test "Double Import" "examples/double_import.fox" "Common Function Called Module A Called"

# 7. Global Registry Import (Tagger)
run_test "Global Registry Import" "examples/global_id_test.fox" "Hasil Tambah (via ID 100): 70 Hasil Kurang (via ID 101): 30"
