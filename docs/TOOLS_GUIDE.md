# Morph Tools Guide - Debugging & Analysis

**Last Updated:** 2026-01-05
**Engineer:** Claude Code + User (Vzoel Fox)

---

## Overview

Tooling untuk debug, analyze, dan optimize Morph compiler output. **Self-hosted tools** ditulis dalam Fox untuk analyze assembly yang di-generate Morph.

```
┌─────────────────────────────────┐
│  Morph Compiler (.fox → .asm)  │
└────────────┬────────────────────┘
             │ generates
             ↓
    ┌────────────────┐
    │  output.asm    │
    └────────┬───────┘
             │ analyzed by
             ↓
┌─────────────────────────────────┐
│  Morph Tools (dogfooding!)      │
│  - quick_asm_check.sh           │
│  - morph_robot.fox              │
│  - asm_parser.fox               │
└─────────────────────────────────┘
```

---

## Tools Directory

### 1. `quick_asm_check.sh` ⚡ **READY TO USE**

**Purpose:** Lightweight assembly validator & debugger

**Features:**
- ✅ Undefined symbol detection
- ✅ Stack depth analysis
- ✅ Section verification (.data, .bss, .text)
- ✅ Function size analysis
- ✅ Automated diagnosis & recommendations

**Usage:**
```bash
./tools/quick_asm_check.sh <asm_file>

# Example: Check N1 compiler output
./bootstrap/morph.sh apps/compiler/src/main.fox > build/n1.asm
./tools/quick_asm_check.sh build/n1.asm
```

**Output Example:**
```
=========================================
  QUICK ASM CHECK - N1 Debugger
=========================================
File: build/n1.asm

=== 1. Undefined Symbol Detection ===
🔴 NASM assembly failed

Undefined symbols found: 54

Top 10 undefined symbols:
heap_current_ptr
heap_end_ptr
var_POOLS_INITIALIZED
var_VECTOR_DATA_POOL
...

Breakdown:
  var_* symbols: 50
  heap_* symbols: 3
  Pool/Arena symbols: 6

🔴 DIAGNOSIS: Bootstrap compiler limitation
   → No BSS section generation for cross-module globals
   → Solution: Use N1 compiler or add BSS generation

=== 2. Stack Depth Analysis ===
Push instructions: 172
Pop instructions: 175
Balance: -3
✅ Stack balance looks healthy

=== 3. Section Verification ===
Sections found:
  .data: 12
  .bss: 2
  .text: 12

========================================
  SUMMARY
========================================
🔴 Assembly has errors - Cannot link

Recommended actions:
  1. Fix cross-module globals (add BSS generation)
  2. Or use N1 compiler instead of bootstrap
  3. Compile memory_pool.fox separately
  4. Link object files together
```

**When to Use:**
- ✅ After compiling with bootstrap compiler
- ✅ Debugging undefined symbol errors
- ✅ Checking stack balance issues
- ✅ Verifying section structure

---

### 2. `morph_robot.fox` 🤖 **IN DEVELOPMENT**

**Purpose:** Comprehensive assembly analyzer & debugger (self-hosted)

**Features (Planned):**
- Symbol table building
- Control flow analysis
- Stack frame tracking
- Crash prediction
- Performance profiling
- Interactive debugging

**Architecture:**
```fox
fungsi mulai()
    ; Load ASM file
    load_asm_file("build/output.asm")

    ; Phase 1: Parse & build symbol table
    parse_symbols()

    ; Phase 2: Analyze stack usage
    analyze_stack()

    ; Phase 3: Check for undefined refs
    check_undefined_symbols()

    ; Phase 4: Generate report
    print_report()
tutup_fungsi
```

**Status:** 🚧 Skeleton implemented, needs:
- File I/O integration
- Proper string parsing
- Symbol resolution logic
- Control flow graph building

**Usage (Future):**
```bash
# Compile morph_robot itself
./bootstrap/morph.sh tools/morph_robot.fox > build/morph_robot.asm
nasm -felf64 build/morph_robot.asm -o build/morph_robot.o
ld build/morph_robot.o -o build/morph_robot

# Analyze target ASM
./build/morph_robot build/n1_compiler.asm

# Output:
# 🔴 STACK OVERFLOW DETECTED at function: init_globals
# 🔴 UNDEFINED SYMBOL: var_POOLS_INITIALIZED (line 1315)
# 🟡 WARNING: Large string init (500+ bytes)
# ✅ SUGGESTIONS: Split init_globals, add BSS generation
```

---

### 3. `asm_parser.fox` 📝 **LIBRARY**

**Purpose:** Reusable assembly parsing utilities

**Functions:**
```fox
; Line type detection
fungsi is_empty_line(line) → int
fungsi is_comment_line(line) → int
fungsi is_label_line(line) → int
fungsi is_directive_line(line) → int
fungsi is_instruction_line(line) → int

; Instruction analysis
fungsi count_push_instructions(line) → int
fungsi count_pop_instructions(line) → int
fungsi has_undefined_symbol(line) → int

; Statistics
fungsi count_lines_by_type(lines_vec) → int
```

**Usage:**
```fox
ambil "tools/asm_parser.fox"

fungsi analyze_my_asm()
    var lines = vec_create(1000)
    ; ... load lines ...

    var stats = count_lines_by_type(lines)
    ; Output:
    ; Total lines: 1813
    ; Labels: 76
    ; Instructions: 500
tutup_fungsi
```

**When to Use:**
- Building custom analysis tools
- Extending morph_robot.fox
- Creating domain-specific validators

---

## Workflow: Debugging N1 Crash

### Scenario: N1 Compiler Crashes

**Step 1: Compile N1**
```bash
timeout 120s ./bootstrap/morph.sh apps/compiler/src/main.fox > build/n1.asm 2>&1
```

**Step 2: Quick Check**
```bash
./tools/quick_asm_check.sh build/n1.asm
```

**Expected Output:**
```
🔴 Undefined symbols found: 54
  var_* symbols: 50

🔴 DIAGNOSIS: Bootstrap compiler limitation
   → No BSS section for cross-module globals
```

**Step 3: Actionable Fixes**

**Option A: Fix Bootstrap Codegen (Add BSS)**
```bash
# Edit bootstrap/lib/codegen.sh
# Add BSS section generation for imported globals

section .bss
    heap_start_ptr   resq 1
    heap_current_ptr resq 1
    heap_end_ptr     resq 1
    var_POOLS_INITIALIZED resq 1  ; ← ADD THIS
    var_VECTOR_DATA_POOL resq 1   ; ← ADD THIS
    ...
```

**Option B: Separate Compilation + Linking**
```bash
# Compile libs separately
./bootstrap/morph.sh lib/memory_pool.fox > build/pool.asm
./bootstrap/morph.sh lib/memory_arena.fox > build/arena.asm
./bootstrap/morph.sh lib/vector.fox > build/vector.asm

# Assemble
nasm -felf64 build/pool.asm -o build/pool.o
nasm -felf64 build/arena.asm -o build/arena.o
nasm -felf64 build/vector.asm -o build/vector.o

# Compile main (will still have undefined refs)
./bootstrap/morph.sh examples/chess_complete.fox > build/chess.asm
nasm -felf64 build/chess.asm -o build/chess.o

# Link everything together
ld build/chess.o build/pool.o build/arena.o build/vector.o -o build/chess

# Expected: Undefined symbols resolved!
```

**Option C: Use N1 Compiler (Once Fixed)**
```bash
# Fix N1 crash first (Fase 1)
# Then N1 will handle cross-module globals natively
./build/n1_compiler examples/chess_complete.fox > build/chess_n1.asm
nasm -felf64 build/chess_n1.asm && ./a.out
```

---

## Workflow: Stack Overflow Detection

### Scenario: Init Globals Too Large

**Step 1: Quick Check**
```bash
./tools/quick_asm_check.sh build/n1.asm
```

**Output:**
```
=== 4. Function Analysis ===
  init_globals: 450 lines
  🔴 WARNING: init_globals too large (450 lines)
     → Known to cause stack overflow
     → Solution: Split into smaller functions
```

**Step 2: Fix Source**
```fox
; Before (crash):
fungsi init_globals()
    var s1 = "..."  ; 500 string constants
    var s2 = "..."
    ... ; 450 lines
tutup_fungsi

; After (fixed):
fungsi init_constants_part1()
    var s1 = "..."
    ... ; 100 lines
tutup_fungsi

fungsi init_constants_part2()
    var s100 = "..."
    ... ; 100 lines
tutup_fungsi

fungsi init_globals()
    init_constants_part1()
    init_constants_part2()
    ... ; Small orchestrator
tutup_fungsi
```

---

## Future Tools (Roadmap)

### 1. `morph_profiler.fox` (Priority 1)
- Measure compilation time per module
- Track memory usage during compile
- Generate flame graphs

### 2. `morph_lint.fox` (Priority 2)
- Style checking
- Best practice validation
- Security vulnerability scanning

### 3. `morph_bench.fox` (Priority 3)
- Benchmark suite runner
- Regression testing
- Performance tracking over time

### 4. `morph_repl.fox` (Priority 4)
- Interactive Fox REPL
- Live assembly inspection
- Step-through debugging

---

## Best Practices

### When to Use Each Tool

| Scenario | Tool | Why |
|----------|------|-----|
| Quick validation | `quick_asm_check.sh` | Fast, no dependencies |
| Undefined symbols | `quick_asm_check.sh` | Detailed breakdown |
| Stack analysis | `quick_asm_check.sh` | Push/pop balance |
| Deep analysis | `morph_robot.fox` | Full symbol table |
| Custom checks | `asm_parser.fox` | Build your own |

### Development Workflow

```bash
# 1. Write Fox code
vim my_program.fox

# 2. Compile
./bootstrap/morph.sh my_program.fox > build/my_program.asm

# 3. Quick check
./tools/quick_asm_check.sh build/my_program.asm

# 4. If errors: fix source, goto 2
# 5. If clean: assemble & link
nasm -felf64 build/my_program.asm -o build/my_program.o
ld build/my_program.o -o build/my_program

# 6. Run
./build/my_program
```

---

## Contributing

### Adding a New Tool

1. **Create in `tools/`:**
```bash
vim tools/my_tool.fox
```

2. **Document in this guide:**
```markdown
### X. `my_tool.fox`
**Purpose:** ...
**Features:** ...
**Usage:** ...
```

3. **Test:**
```bash
./bootstrap/morph.sh tools/my_tool.fox > build/my_tool.asm
./tools/quick_asm_check.sh build/my_tool.asm
```

4. **Add to Makefile** (future):
```make
tools: morph_robot my_tool
```

---

## Conclusion

**Philosophy:** **Dogfooding** - Morph tools written in Fox, analyzed by Morph tools.

**Benefits:**
- ✅ Self-hosted debugging
- ✅ Rapid iteration (Fox → ASM → Analyze)
- ✅ No external dependencies
- ✅ Learning by doing

**Status:**
- ✅ `quick_asm_check.sh` - Production ready
- 🚧 `morph_robot.fox` - In development
- ✅ `asm_parser.fox` - Library ready

**Next Steps:**
1. Fix N1 crash (Fase 1)
2. Complete morph_robot.fox
3. Add profiling tools
4. Build test suite

**Ready untuk debug N1 sekarang dengan `quick_asm_check.sh`!**
