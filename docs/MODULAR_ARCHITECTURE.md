# Modular Architecture

**Last Updated:** 2026-01-05
**Engineers:** Claude Code (Anthropic), Kiro (AWS Q CLI Agent)

---

## Session Log

### 2026-01-05 (Kiro)
- Implemented full ID-based import system across all compiler modules
- Updated indeks.fox with complete ID registrations (1010-1056, 1100-1146)
- Verified all 20 modules compile successfully (1,951 source → 30,870 ASM lines)
- Cleaned up duplicate files, moved to `apps/compiler/src/archive/`

### 2026-01-04 (Claude Code)
- Designed modular architecture with ID-based imports
- Created initial documentation

---

**File organization, ID registry, and module responsibilities**

---

## Directory Structure

```
/root/asm/
├── lib/                          # Standard Library
│   ├── morphroutine.fox         # Runtime + AST (ID 400-402, 410-418)
│   ├── trickster_tokenize.fox   # Tokenizer (ID 220-222)
│   ├── trickster_parse.fox      # Parser (ID 223-224)
│   ├── vector.fox               # Dynamic arrays (ID 340-344)
│   ├── hashmap.fox              # Hash tables (ID 330-333)
│   ├── string_utils.fox         # String manipulation (ID 380-388)
│   ├── format.fox               # Formatting (ID 320-324)
│   ├── buffer.fox               # Buffers (ID 310-316)
│   ├── file_io.fox              # File I/O (ID 318-319)
│   ├── bool.fox                 # Boolean logic (ID 200-209)
│   ├── circuit_breaker.fox      # Fault tolerance (ID 210-217)
│   ├── json.fox                 # JSON parsing (ID 450-459)
│   └── math.fox                 # Math operations (ID 100-105)
│
├── apps/compiler/src/           # Self-Hosted Compiler
│   ├── exprs.fox                # Expression parser (ID 1150-1152)
│   ├── parser.fox               # Main parser (52 lines, WIP)
│   │
│   ├── parser_helpers_import.fox    # Import handling (ID 1100-1103)
│   ├── parser_helpers_struct.fox    # Struct definitions (ID 1110-1112)
│   ├── parser_helpers_fungsi.fox    # Functions (ID 1120-1121)
│   ├── parser_helpers_jika.fox      # Conditionals (ID 1122-1125)
│   ├── parser_helpers_loop.fox      # Loops (ID 1126-1127)
│   ├── parser_helpers_stmt.fox      # Statements (ID 1130-1139)
│   │
│   ├── parser_dispatch_import.fox       # Import dispatcher (ID 1140)
│   ├── parser_dispatch_struct.fox       # Struct dispatcher (ID 1141)
│   ├── parser_dispatch_control.fox      # Control flow (ID 1142)
│   ├── parser_dispatch_var_struct.fox   # Var struct (ID 1143)
│   ├── parser_dispatch_var_simple.fox   # Var simple (ID 1144)
│   ├── parser_dispatch_cetak.fox        # Print (ID 1145)
│   └── parser_dispatch_panggil.fox      # Function calls (ID 1146)
│
├── bootstrap/                   # Bootstrap Compiler
│   ├── morph.sh                 # Main entry point
│   ├── lib/parser.sh            # Parser logic
│   ├── lib/codegen.sh           # Code generator
│   └── lib/trickster.sh         # Expression evaluator
│
├── tools/                       # Build Tools
│   ├── compile_fragmented.sh   # Batch compilation
│   └── merge_deterministic.sh  # Assembly merging
│
├── examples/                    # Example Programs
├── build/                       # Compilation Output
├── docs/                        # Documentation
│   ├── COMPILATION_STRATEGY.md
│   ├── MODULAR_ARCHITECTURE.md (this file)
│   └── AST_EXPRESSION_PARSER.md
│
└── indeks.fox                   # ID Registry (CRITICAL!)
```

---

## ID Registry (`indeks.fox`)

**Central mapping of all function IDs for selective imports.**

### Purpose
- Enable selective imports: `Ambil 340, 341, 342` instead of full file
- Avoid namespace conflicts
- Document function ownership
- Support versioning

### ID Ranges (Current Allocation)

| Range | Module | Purpose |
|-------|--------|---------|
| 100-105 | lib/math.fox | Math operations |
| 200-209 | lib/bool.fox | Boolean logic, unit isolation |
| 210-217 | lib/circuit_breaker.fox | Fault tolerance |
| 220-222 | lib/trickster_tokenize.fox | Tokenization |
| 223-224 | lib/trickster_parse.fox | AST building |
| 310-316 | lib/buffer.fox | Buffer management |
| 318-319 | lib/file_io.fox | File operations |
| 320-324 | lib/format.fox | String formatting |
| 330-333 | lib/hashmap.fox | Hash tables |
| 340-344 | lib/vector.fox | Dynamic arrays |
| 380-388 | lib/string_utils.fox | String manipulation |
| 390-391 | lib/string_utils.fox | str_to_int, str_index_of |
| 400-402 | lib/morphroutine.fox | Runtime structures |
| 410-418 | lib/morphroutine.fox | AST structures |
| 450-459 | lib/json.fox | JSON parsing |
| 500-513 | lib/kernel/signals.fox | Signal handling |
| 1100-1103 | apps/compiler/src/parser_helpers_import.fox | Import parsing |
| 1110-1112 | apps/compiler/src/parser_helpers_struct.fox | Struct parsing |
| 1120-1121 | apps/compiler/src/parser_helpers_fungsi.fox | Function parsing |
| 1122-1125 | apps/compiler/src/parser_helpers_jika.fox | Conditional parsing |
| 1126-1127 | apps/compiler/src/parser_helpers_loop.fox | Loop parsing |
| 1130-1139 | apps/compiler/src/parser_helpers_stmt.fox | Statement helpers |
| 1140 | apps/compiler/src/parser_dispatch_import.fox | Import dispatch |
| 1141 | apps/compiler/src/parser_dispatch_struct.fox | Struct dispatch |
| 1142 | apps/compiler/src/parser_dispatch_control.fox | Control dispatch |
| 1143 | apps/compiler/src/parser_dispatch_var_struct.fox | Var struct dispatch |
| 1144 | apps/compiler/src/parser_dispatch_var_simple.fox | Var simple dispatch |
| 1145 | apps/compiler/src/parser_dispatch_cetak.fox | Print dispatch |
| 1146 | apps/compiler/src/parser_dispatch_panggil.fox | Call dispatch |
| 1150-1152 | apps/compiler/src/exprs.fox | Expression parsing |

### Reserved Ranges

| Range | Purpose |
|-------|---------|
| 1000-1999 | Compiler modules |
| 2000-2999 | Kernel modules |
| 3000-3999 | Standard library extensions |
| 4000-4999 | User-defined libraries |

---

## Module Responsibilities

### Standard Library

#### `lib/morphroutine.fox`
**Purpose:** Runtime structures + AST foundation
**Exports:**
- Task/Context structures (scheduler metadata)
- ASTNode structure (expression tree)
- AST builder functions (ast_create_*, ast_get_*)
**Dependencies:** None (pure data)

#### `lib/trickster_tokenize.fox`
**Purpose:** Expression tokenization
**Exports:**
- Token structure
- Precedence constants
- trickster_tokenize() - String → Token vector
- trickster_get_precedence() - Operator precedence lookup
**Dependencies:** Vector, String Utils

#### `lib/trickster_parse.fox`
**Purpose:** AST building via Shunting-yard algorithm
**Exports:**
- trickster_parse_to_ast() - Token vector → AST
- trickster_build_ast_from_rpn() - RPN → AST tree
**Dependencies:** Tokenize, AST structures

---

### Compiler Modules

#### `apps/compiler/src/exprs.fox`
**Purpose:** Expression → Assembly codegen
**Exports:**
- expr_parse() - String → AST
- expr_emit_asm() - AST → Assembly (recursive)
- expr_parse_and_emit() - Convenience wrapper
**Dependencies:** Trickster (tokenize + parse), AST

#### Parser Helpers (6 modules)
**Naming:** `parser_helpers_<domain>.fox`
**Pattern:** Pure logic, called by dispatchers
**Dependencies:** Stdlib only (Vector, String, etc)

| Module | Handles | Functions |
|--------|---------|-----------|
| parser_helpers_import.fox | ambil, Ambil, Daftar, indeks | handle_import_* |
| parser_helpers_struct.fox | struktur, tutup_struktur, fields | handle_struct_* |
| parser_helpers_fungsi.fox | fungsi, tutup_fungsi | handle_fungsi_* |
| parser_helpers_jika.fox | jika, lain, tutup_jika | handle_jika, handle_lain, handle_tutup_jika |
| parser_helpers_loop.fox | selama, tutup_selama | handle_selama, handle_tutup_selama |
| parser_helpers_stmt.fox | var, cetak, panggil, etc | is_var_line, is_cetak_line, etc |

#### Parser Dispatchers (7 modules)
**Naming:** `parser_dispatch_<domain>.fox`
**Pattern:** Entry points, call helpers
**Dependencies:** Helpers ONLY (no stdlib re-imports!)

| Module | Dispatches | Calls |
|--------|-----------|-------|
| parser_dispatch_import.fox | Import keywords | handle_import_* |
| parser_dispatch_struct.fox | Struct definitions | handle_struct_* |
| parser_dispatch_control.fox | Control flow | handle_fungsi_*, handle_jika_*, handle_selama_* |
| parser_dispatch_var_struct.fox | Struct instantiation | handle_var_struct |
| parser_dispatch_var_simple.fox | Simple var decl | handle_var_simple (inline) |
| parser_dispatch_cetak.fox | Print statements | cetak logic (inline) |
| parser_dispatch_panggil.fox | Function calls | panggil logic (inline) |

---

## Import Patterns

### Full Import
```fox
ambil "lib/vector.fox"
```
**Use when:** Importing entire module for first time

### Selective Import
```fox
Ambil 340, 341, 342  ; vec_create, vec_push, vec_get
```
**Use when:** Only need specific functions (more efficient)

### No Import (Inheritance)
```fox
; dispatcher.fox inherits from parent parser.fox
; NO Ambil needed!
fungsi dispatch_import(line)
   var tokens = vec_create(10)  ; vec_create already available
tutup_fungsi
```
**Use when:** Child module called by parent that already imported

---

## Adding a New Module

### Step 1: Choose ID Range
Check `indeks.fox` for available ranges:
```fox
# Available: 225-299 (Trickster extensions)
# Available: 1147-1199 (Compiler dispatchers)
# Available: 2000-2999 (Kernel modules)
```

### Step 2: Create Module
```fox
; lib/my_module.fox
; Description: What this module does
; ID Range: XXX-YYY

### XXX
fungsi my_function()
   ; Implementation
tutup_fungsi
```

**Keep < 150 lines when possible!**

### Step 3: Compile Independently
```bash
timeout 45s ./bootstrap/morph.sh lib/my_module.fox > build/my_module.asm
wc -l build/my_module.asm  # Verify output
```

### Step 4: Register in `indeks.fox`
```fox
# My Module (XXX-YYY)
Daftar "lib/my_module.fox" = XXX-YYY  ; Brief description
```

### Step 5: Document
Update `docs/MODULAR_ARCHITECTURE.md` with:
- ID range allocation
- Module responsibility
- Dependencies

---

## File Size Guidelines

| Category | Lines | Status | Example |
|----------|-------|--------|---------|
| Ideal | < 150 | ✅ Sweet spot | morphroutine.fox (150) |
| Acceptable | 150-200 | ⚠️ May timeout | trickster_tokenize.fox (207) |
| Problematic | 200-300 | ❌ Split recommended | (none current) |
| Impossible | 300+ | ❌ Will timeout | parser.fox.monolithic_backup (520) |

**Rule of thumb:** If > 150 lines, consider splitting by responsibility.

---

## Module Naming Conventions

| Pattern | Example | Purpose |
|---------|---------|---------|
| `<domain>.fox` | `vector.fox` | Core library module |
| `<domain>_<detail>.fox` | `string_utils.fox` | Library with specialization |
| `<component>_<action>.fox` | `trickster_tokenize.fox` | Multi-part system |
| `parser_helpers_<domain>.fox` | `parser_helpers_jika.fox` | Helper logic |
| `parser_dispatch_<domain>.fox` | `parser_dispatch_control.fox` | Dispatcher entry point |

**Consistency aids navigation and understanding.**
