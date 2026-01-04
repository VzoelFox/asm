# Morph Programming Language

**Self-hosting compiler with modular architecture and AST-based expression parsing.**

---

## Quick Start

### Compile a Program
```bash
./bootstrap/morph.sh examples/hello.fox > output.asm
nasm -f elf64 output.asm -o output.o
ld output.o -o output
./output
```

### Compile Modular Components
```bash
# AST Foundation (always compile first)
./bootstrap/morph.sh lib/morphroutine.fox > build/morphroutine.asm

# Trickster Expression Parser
./bootstrap/morph.sh lib/trickster_tokenize.fox > build/trickster_tokenize.asm
./bootstrap/morph.sh lib/trickster_parse.fox > build/trickster_parse.asm

# Compiler Modules
./bootstrap/morph.sh apps/compiler/src/exprs.fox > build/exprs.asm
```

---

## Architecture Overview

### Compilation Strategy: **Bottom-Up**

```
Layer 1: AST Structures (morphroutine.fox)
         ↓
Layer 2: Tokenization (trickster_tokenize.fox)
         ↓
Layer 3: AST Building (trickster_parse.fox)
         ↓
Layer 4: Expression Compiler (exprs.fox)
         ↓
Layer 5: Parser Dispatchers (13 modular files)
```

**Why Bottom-Up?**
- Pure data structures compile first (zero dependencies)
- No circular imports
- Each layer independently testable
- Bootstrap compiler limit: ~150 lines per file (proven up to 207 lines)

---

## Project Structure

```
/root/asm/
├── lib/                           # Standard library
│   ├── morphroutine.fox          # AST structures (ID 400-402, 410-418)
│   ├── trickster_tokenize.fox    # Tokenizer (ID 220-222)
│   ├── trickster_parse.fox       # AST builder (ID 223-224)
│   ├── vector.fox, hashmap.fox   # Data structures
│   └── string_utils.fox, format.fox
│
├── apps/compiler/src/            # Self-hosted compiler
│   ├── exprs.fox                 # Expression parser (ID 1150-1152)
│   ├── parser_helpers_*.fox      # 6 helper modules (ID 1100-1139)
│   ├── parser_dispatch_*.fox     # 7 dispatcher modules (ID 1140-1146)
│   └── parser.fox                # Main parser entry (WIP)
│
├── bootstrap/                    # Bootstrap compiler (Shell-based)
│   └── morph.sh                  # N0 compiler (150 line limit)
│
├── tools/                        # Build tools
│   ├── compile_fragmented.sh    # Batch compilation
│   └── merge_deterministic.sh   # Assembly merging
│
├── examples/                     # Test programs
├── build/                        # Compilation output
├── docs/                         # Documentation
└── indeks.fox                    # ID registry (central mapping)
```

---

## Key Concepts

### 1. **ID Registry System** (`indeks.fox`)
Every function has a unique ID for selective imports:

```fox
# Full import
ambil "lib/vector.fox"

# Selective import (efficient)
Ambil 340, 341, 342  ; vec_create, vec_push, vec_get
```

### 2. **AST-Based Expression Parsing**
Deterministic operator precedence using Shunting-yard algorithm:

```fox
var x = 10 + y * 2    ; Parse → AST → Assembly
```

**AST Tree:**
```
     BINOP(+)
    /        \
NUMBER(10)  BINOP(*)
           /        \
       IDENT(y)  NUMBER(2)
```

### 3. **Modular Compilation**
Each module < 150 lines compiles independently:

- **17 modules compiled successfully** ✅
- **Total: 1,912 lines → 25,325 lines assembly**
- **Success rate: 100%**

---

## Compilation Results

| Module | Lines | Assembly | Status |
|--------|-------|----------|--------|
| morphroutine.fox (AST) | 150 | 1448 | ✅ |
| trickster_tokenize.fox | 207 | 1915 | ✅ |
| trickster_parse.fox | 139 | 1613 | ✅ |
| exprs.fox | 126 | 1517 | ✅ |
| parser_helpers (6 files) | 643 | 9103 | ✅ |
| parser_dispatchers (7 files) | 538 | 10321 | ✅ |

**Bootstrap Compiler Limits:**
- Sweet spot: < 150 lines per file
- Proven: Up to 207 lines (trickster_tokenize.fox)
- Import optimization critical (no redundant Ambil statements)

---

## Documentation

- **[COMPILATION_STRATEGY.md](docs/COMPILATION_STRATEGY.md)** - Bottom-up approach, dependency management
- **[MODULAR_ARCHITECTURE.md](docs/MODULAR_ARCHITECTURE.md)** - File structure, ID ranges, module responsibilities
- **[AST_EXPRESSION_PARSER.md](docs/AST_EXPRESSION_PARSER.md)** - AST design, Trickster integration, codegen

---

## Development Guidelines

### Before Making Changes:
1. Read `docs/COMPILATION_STRATEGY.md` to understand dependency order
2. Check `indeks.fox` for available ID ranges
3. Keep new modules < 150 lines when possible

### Testing a Module:
```bash
timeout 45s ./bootstrap/morph.sh path/to/module.fox > build/output.asm
wc -l build/output.asm  # Verify assembly generated
```

### Adding a New Module:
1. Create file (< 150 lines)
2. Compile independently
3. Register IDs in `indeks.fox`
4. Document in relevant docs/*.md

---

## Current Status

**✅ Proven Working:**
- AST foundation (morphroutine.fox)
- Expression parser (Trickster + exprs.fox)
- Modular parser components (13 modules)
- Import optimization strategy

**🚧 Work in Progress:**
- Full parser.fox integration (inline dispatchers)
- Self-hosting bootstrap (compile compiler with itself)

**📋 Future:**
- Type checker using AST
- Optimization passes (constant folding, dead code elimination)
- Multi-backend codegen (ARM, WASM)

---

## Contributing

See active development journal: `AGENTS2.md`

**Key Principles:**
- Modular over monolithic
- Bottom-up dependency chain
- Compile-test each layer independently
- Document ID allocations in indeks.fox

---

## License

MIT License - See LICENSE file

---

## Credits

**Primary Development:** Vzoel Fox
**Architecture Strategy:** Bottom-up AST-first approach
**Bootstrap Compiler:** Shell-based N0 implementation
