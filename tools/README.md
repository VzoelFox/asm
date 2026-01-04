# Morph Compilation Tools

Tools for fragmented compilation and deterministic merging.

---

## Overview

These tools enable compilation of large files by fragmenting them into smaller, manageable units that compile within bootstrap compiler limitations.

**Problem:** Bootstrap compiler times out on files > 300 lines
**Solution:** Fragment → Compile → Merge (deterministic)

---

## Tools

### 1. compile_fragmented.sh

**Purpose:** Batch compilation using sandbox isolation

**Usage:**
```bash
./tools/compile_fragmented.sh <input.fox> [output.asm]
```

**Features:**
- Splits file into fragments (default: 100 lines per fragment)
- Compiles each fragment in isolated sandbox (max 8 concurrent)
- 30s timeout per fragment (not total file)
- Merges fragments into cohesive shard
- Detailed logging with color output

**Example:**
```bash
./tools/compile_fragmented.sh apps/compiler/src/parser.fox parser_fragmented.asm

# Output:
# [INFO] Fragmented compilation started
# [INFO] Total lines: 518
# [INFO] Required batches: 6
# [Sandbox 0] Compiling fragment_0.fox...
# [Sandbox 0] ✓ Compiled (1311 lines assembly)
# ...
# [INFO] ✓ Merge complete: parser_fragmented.asm (2500 lines)
```

**Configuration:**
```bash
# Edit these variables in the script:
BATCH_SIZE=100          # Lines per fragment
MAX_FRAGMENTS=8         # Max sandboxes
```

**Limitations:**
- Fragments may break mid-function (syntax incomplete)
- Current merge is simple concatenation (Phase 1)
- Smart merge with deduplication in Phase 2

---

### 2. merge_deterministic.sh

**Purpose:** Deterministic assembly merge algorithm

**Usage:**
```bash
./tools/merge_deterministic.sh <output.asm> <fragment1.asm> [fragment2.asm ...]
```

**Features:**
- **Section Deduplication:** Removes duplicate .data, .bss, .text headers
- **Symbol Sorting:** Functions sorted alphabetically (deterministic order)
- **Constant Merging:** Deduplicates constants (HEAP_SIZE, SYS_*)
- **BSS Merging:** Combines variable declarations, sorted

**Example:**
```bash
./tools/merge_deterministic.sh output.asm fragment_0.asm fragment_1.asm fragment_2.asm

# Output:
# [Phase 1] Extracting sections...
# [Phase 2] Deduplicating sections...
# [Phase 3] Building final shard...
# [Merge] ✓ Complete: output.asm
#
# === Merge Statistics ===
# Output lines:      5432
# Unique functions:  87
# Unique variables:  142
```

**Strategy:**
```
1. Extract sections from each fragment:
   - .data (constants, strings)
   - .bss (variables)
   - .text (code)

2. Deduplicate:
   - Sort constants alphabetically
   - Merge variables (remove duplicates)
   - Keep one copy of runtime functions

3. Build final shard:
   - Header (default rel)
   - section .data (merged)
   - section .text (runtime + user functions sorted)
   - section .bss (merged + sorted)
```

**Merge Quality:**
```bash
MERGE_STRATEGY=simple     # Concatenate (fast, may have duplicates)
MERGE_STRATEGY=smart      # Deduplicate + sort (default)
MERGE_STRATEGY=ast        # AST-level merge (future)
```

---

### 3. split_smart.sh

**Purpose:** Parse-aware file splitting

**Usage:**
```bash
./tools/split_smart.sh <input.fox> [output_dir] [max_fragment_size]
```

**Features:**
- **Syntactic Boundaries:** Only splits at safe points
- **Context Tracking:** Monitors function/struct nesting
- **Brace Depth:** Ensures all blocks closed before split
- Returns fragment count for caller

**Safe Split Points:**
```
✅ Between functions (after tutup_fungsi)
✅ Between structs (after tutup_struktur)
✅ Between top-level statements (brace_depth == 0)

❌ Inside function body
❌ Inside struct definition
❌ Inside control flow (jika/selama)
```

**Example:**
```bash
./tools/split_smart.sh apps/compiler/src/main.fox /tmp/fragments 150

# Output:
# [Smart Split] Input: main.fox
# [Smart Split] Max fragment size: 150 lines
# [Fragment 0] 147 lines (safe boundary found)
# [Fragment 1] 149 lines (safe boundary found)
# [Fragment 2] 85 lines (EOF)
# [Smart Split] Created 3 fragments
# 3
```

**Algorithm:**
```python
for each line:
    write to current fragment

    if line == "fungsi":
        in_function = True
    if line == "tutup_fungsi":
        in_function = False

    if line == "jika" or "selama":
        brace_depth++
    if line == "tutup_jika" or "tutup_selama":
        brace_depth--

    if fragment_size >= max_size:
        if not in_function and brace_depth == 0:
            split here (safe boundary)
```

**Status:** ⚠️ Experimental (not yet integrated)

---

## Workflow: Fragmented Compilation

### Step 1: Smart Split (Optional)
```bash
./tools/split_smart.sh large_file.fox /tmp/frags 150
```

### Step 2: Fragmented Compile
```bash
./tools/compile_fragmented.sh large_file.fox output.asm
```
**OR** manually per fragment:
```bash
for frag in /tmp/frags/fragment_*.fox; do
    timeout 20s ./bootstrap/morph.sh "$frag" > "${frag%.fox}.asm"
done
```

### Step 3: Deterministic Merge
```bash
./tools/merge_deterministic.sh final.asm /tmp/frags/*.asm
```

### Step 4: Assemble & Link
```bash
nasm -f elf64 final.asm -o final.o
ld final.o -o final_binary
```

---

## Integration with Morph Build System

### Future: Makefile Integration
```makefile
# Compile large self-hosted compiler
apps/compiler/morph_v1: apps/compiler/src/*.fox
	@echo "Compiling self-hosted compiler (fragmented)..."
	./tools/compile_fragmented.sh apps/compiler/src/main.fox morph_v1.asm
	nasm -f elf64 morph_v1.asm -o morph_v1.o
	ld morph_v1.o -o apps/compiler/morph_v1
	@echo "✓ Self-hosted compiler ready"
```

---

## Troubleshooting

### Fragment Compilation Fails
```
[ERROR] [Sandbox 2] ✗ Compilation failed or timeout
```

**Diagnosis:**
1. Check fragment syntax: `cat /tmp/morph_fragments_*/fragment_2.fox`
2. Fragment may be mid-function (incomplete)
3. Use `split_smart.sh` for better boundaries

**Solution:**
- Adjust `BATCH_SIZE` (try 80 or 120)
- Use `split_smart.sh` first
- Manually verify fragment syntax

### Merge Has Duplicates
```
section .data
    HEAP_SIZE equ 256MB
    HEAP_SIZE equ 256MB  ; duplicate!
```

**Solution:**
```bash
MERGE_STRATEGY=smart ./tools/merge_deterministic.sh output.asm frags/*.asm
```

### Assembly Linking Fails
```
undefined reference to `vec_create'
```

**Cause:** Imported functions not included in merge

**Solution:**
- Ensure fragment includes stdlib (lib/*.fox)
- Check BSS section has all `var_*` declarations
- May need `ambil` instead of `Ambil`

---

## Performance

### Benchmark: parser.fox (518 lines)

**Bootstrap (monolithic):**
- Timeout after 90s ❌

**Fragmented (6 batches):**
- Fragment 0: 20s ✅
- Fragments 1-5: Failed (syntax incomplete) ❌
- Total: 1/6 compiled

**Smart Split + Fragmented:**
- (Not tested yet - awaiting helpers)

---

## Future Enhancements

### Phase 2: Smart Merge
- Dependency graph resolution
- Forward reference handling
- Dead code elimination

### Phase 3: Parallel Compilation
```bash
# Compile fragments in parallel (8 cores)
for frag in /tmp/frags/*.fox; do
    timeout 20s ./bootstrap/morph.sh "$frag" > "${frag%.fox}.asm" &
done
wait
```

### Phase 4: Incremental Compilation
```bash
# Only recompile changed fragments
make -j8 fragments
```

---

## See Also

- `../docs/FAULT_TOLERANCE_ARCHITECTURE.md` - Overall architecture
- `../examples/README.md` - Test files
- `../bin/morph_cleaner.sh` - Memory cleanup daemon
