# Morph Examples & Tests

Collection of test files and examples demonstrating Morph features.

---

## Test Files (Fault Tolerance)

### Integration Tests

**`test_integrated_recovery.fox`**
- **Purpose:** Full integration test for fault tolerance stack
- **Tests:** Signal handling, Trickster, Boolean logic, Circuit breaker
- **Dependencies:** lib/bool.fox, lib/circuit_breaker.fox, lib/trickster.fox, lib/kernel/signals.fox
- **Expected Output:** "✓ ALL TESTS PASSED"

### Memory & Checkpoint Tests

**`test_checkpoint_pure.fox`**
- **Purpose:** Test sys_mem_checkpoint and sys_alloc
- **Tests:** Memory allocation, checkpoint creation, restoration
- **Expected Output:** "Success!" with checkpoint messages

**`test_checkpoint_crash.fox`**
- **Purpose:** Test checkpoint behavior with stdlib dependencies
- **Note:** May fail due to missing vec_* implementations
- **Status:** Demonstrates bootstrap compiler limitations

**`test_runtime_simple.fox`**
- **Purpose:** Basic runtime validation
- **Tests:** Simple arithmetic, cetak() function
- **Expected Output:** "=== TEST SELESAI ==="

### Compiler Simulation

**`test_compiler_simulation.fox`**
- **Purpose:** Simulate compiler behavior with heavy memory usage
- **Tests:** Vector creation, HashMap usage, loop processing
- **Status:** Times out (demonstrates fragmentation need)

### Import System Tests

**`test_with_full_import.fox`**
- **Purpose:** Test `ambil` (full file import) vs `Ambil` (selective import)
- **Tests:** lib/vector.fox integration
- **Expected Output:** Vector operations (create, push, len)

### Debug Tests

**`test_simple_debug.fox`**
- **Purpose:** Minimal test for bootstrap compiler validation
- **Tests:** Function definition, variable, cetak
- **Size:** 8 lines (proven to compile)

**`test_const_asm.fox`**
- **Purpose:** Test const usage in assembly blocks
- **Tests:** Inline assembly with constants
- **Note:** Bootstrap compiler treats const as variables

---

## How to Run Tests

### Basic Test (No Dependencies)
```bash
./bootstrap/morph.sh examples/test_simple_debug.fox > output.asm
nasm -f elf64 output.asm -o output.o
ld output.o -o output
./output
```

### Integration Test (Requires Compilation)
```bash
# After helpers are compiled:
./morph_v1 examples/test_integrated_recovery.fox
# Expected: All tests pass with detailed output
```

### Checkpoint Test
```bash
./bootstrap/morph.sh examples/test_checkpoint_pure.fox > test.asm
nasm -f elf64 test.asm -o test.o
ld test.o -o test
./test
# Expected: "Success!" with checkpoint messages
```

---

## Test Status

| Test | Compiles | Runs | Status |
|------|----------|------|--------|
| test_simple_debug.fox | ✅ | ✅ | PASS |
| test_runtime_simple.fox | ✅ | ✅ | PASS |
| test_checkpoint_pure.fox | ✅ | ✅ | PASS |
| test_with_full_import.fox | ✅ | ❌ | Missing vec_* in BSS |
| test_checkpoint_crash.fox | ⏳ | - | Timeout (complex) |
| test_compiler_simulation.fox | ⏳ | - | Timeout (heavy) |
| test_integrated_recovery.fox | ⏳ | ⏳ | Awaiting helpers |
| test_const_asm.fox | ✅ | ⚠️ | Const treated as var |

**Legend:**
- ✅ Works
- ❌ Fails
- ⏳ Not tested yet (waiting for dependencies)
- ⚠️ Works with caveats

---

## Expected Failures (Known Issues)

### Bootstrap Compiler Limitations

1. **File Size Limit:** ~300 lines max before timeout
2. **Missing BSS Generation:** Imported function locals not in BSS
3. **Const Handling:** Constants treated as variables in assembly
4. **Complex Imports:** `Ambil` (selective) may not inline correctly

### Workarounds

- Use fragmented compilation (tools/compile_fragmented.sh)
- Compile helpers individually
- Keep functions < 200 lines
- Use `ambil` for full imports instead of `Ambil`

---

## Contributing

When adding new test files:

1. Use descriptive names: `test_<feature>_<scenario>.fox`
2. Add comment header explaining purpose
3. Update this README with test description
4. Mark expected output
5. Note dependencies (lib/*.fox)

Example header:
```fox
; Test: Feature Name
; Purpose: What this test validates
; Dependencies: lib/foo.fox (ID 100-109)
; Expected: "Success!" or specific output
```

---

## See Also

- `../docs/FAULT_TOLERANCE_ARCHITECTURE.md` - Architecture overview
- `../tools/README.md` - Compilation tools
- `../lib/README.md` - Standard library documentation
