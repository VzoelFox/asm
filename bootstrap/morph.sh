#!/bin/bash

# Morph Bootstrap Compiler Entry Point

# Set base directory relative to this script
BASE_DIR="$(dirname "$0")"

# Load modules
# Order matters: codegen must be loaded before parser if parser uses it (though passing vars is better)
# But here parser calls codegen functions directly.
source "$BASE_DIR/lib/codegen.sh"
source "$BASE_DIR/lib/parser.sh"

# Default Compiler Source (Updated for self-host refactor)
# If we are compiling the compiler itself (self-host)
COMPILER_SRC="apps/compiler/src/main.fox"

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
    echo "Penggunaan: $0 <file.fox>"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File $INPUT_FILE tidak ditemukan."
    exit 1
fi

# Jalankan parser
parse_file "$INPUT_FILE"
