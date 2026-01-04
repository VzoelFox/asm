# Morph Fault Tolerance Architecture

**Date:** 2026-01-04
**Status:** Implemented (Awaiting Compilation Test)
**Priority:** 4 → 3 → 1 → 2

---

## Overview

Morph sekarang memiliki **fault-tolerant execution model** dengan isolation di level unit/shard. Jika satu unit crash, unit lain tetap berjalan - **tidak perlu rebuild seluruh codebase**.

### Core Principle
> **"Menutup unit/shard yang bermasalah bukan membongkar pasang codebase yang dicurigai"**

---

## Architecture Components

### 1. Signal Handler (Priority 4) - Foundation
**File:** `lib/kernel/signals.fox` (ID 500-513)

**Purpose:** "Peta untuk perjalanan selanjutnya" - crash detection infrastructure

**Capabilities:**
- Detect crashes: SIGSEGV, SIGABRT, SIGFPE, SIGBUS
- Extract crash context (fault address, instruction pointer)
- Track crash count and recursion depth
- Prevent infinite recovery loops (max depth: 10)
- Integration dengan morph_cleaner via SIGUSR1/SIGUSR2

**Key Functions:**
```fox
signal_init()                          // Setup crash handlers
signal_handler_segfault(sig, info, ctx) // Handle segfault
signal_trigger_recovery(crash_state)   // Initiate rollback
signal_freeze_all_children()           // Pause concurrent processes
```

**Critical State:**
```fox
struktur CrashState
    signal_num int        // Signal that caused crash
    error_addr int        // Faulting memory address
    crash_count int       // Total crashes
    recovery_depth int    // Recursion depth (prevent loops)
tutup_struktur
```

---

### 2. Trickster Integration (Priority 3) - Determinism
**File:** `lib/trickster.fox` (ID 220-225)

**Purpose:** "Mengurutkan expresi bukan mengambil acak" - consistent AST generation

**Capabilities:**
- Tokenize expressions with deterministic ordering
- Shunting-yard algorithm for operator precedence
- Reverse Polish Notation (RPN) evaluation
- Context-based variable lookup

**Operator Precedence (Deterministic):**
```
PREC_OR = 1       (||)
PREC_AND = 2      (&&)
PREC_EQ = 3       (==, !=)
PREC_CMP = 4      (<, >, <=, >=)
PREC_SHIFT = 8    (<<, >>)
PREC_ADD = 9      (+, -)
PREC_MUL = 10     (*, /, %)
PREC_UNARY = 11   (!, ~)
```

**Key Functions:**
```fox
trickster_eval(expr_str, context_map)  // Main evaluator
trickster_tokenize(expr_str)           // Tokenizer
trickster_eval_rpn(rpn_queue)          // RPN evaluator
```

**Example Usage:**
```fox
var ctx = map_create(16)
panggil map_put(ctx, "failure_count", 3)
panggil map_put(ctx, "threshold", 5)

var result = trickster_eval("failure_count < threshold", ctx)
// result = TRUE (deterministic!)
```

**Benefits:**
- Same input → same AST → same output
- Cross-platform consistency
- Reproducible builds

---

### 3. Boolean & Unit Isolation (Priority 1) - Testing
**File:** `lib/bool.fox` (ID 200-209)

**Purpose:** Granular fault isolation - test "jika 1 ditutup, apakah crash atau bisa lanjut?"

**Capabilities:**
- Boolean logic (AND, OR, NOT, XOR)
- Unit state management (OPEN, CLOSED, TESTING)
- Checkpoint per unit
- Dependency tracking

**Unit Structure:**
```fox
struktur CompilationUnit
    id int               // Unit identifier
    state int            // UNIT_OPEN, UNIT_CLOSED, UNIT_TESTING
    error_count int      // Errors in this unit
    checkpoint_ptr int   // Snapshot pointer
    dependencies int     // Vector of dependent unit IDs
tutup_struktur
```

**Key Functions:**
```fox
unit_create(unit_id)              // Create isolated unit
unit_close(unit_id)               // Isolate failed unit
unit_can_execute(unit_id)         // Test if unit functional
unit_test_isolation()             // Integration test
```

**Critical Test:**
```fox
unit_close(1)            // Close unit 1 (has error)
unit_can_execute(2)      // → TRUE (unit 2 continues!)
unit_can_execute(3)      // → TRUE (unit 3 continues!)
unit_can_execute(1)      // → FALSE (correctly isolated)
```

**Impact:**
- Type Unknown error di unit 1 → tidak crash entire compiler
- Unit 2 dan 3 tetap compile
- Incremental fixing (fix unit 1, recompile only that unit)

---

### 4. Circuit Breaker (Priority 2) - Integration
**File:** `lib/circuit_breaker.fox` (ID 210-217)

**Purpose:** Orchestrate fault tolerance - integrates signals + trickster + boolean

**State Machine:**
```
CLOSED (normal)
   │ failure_count >= threshold
   ▼
OPEN (failing, block execution)
   │ elapsed_time > timeout
   ▼
HALF_OPEN (testing recovery)
   │ 3 consecutive successes
   ▼
CLOSED (recovered)
```

**Key Functions:**
```fox
cb_create(failure_threshold, timeout_ms)    // Create circuit breaker
cb_can_execute(cb)                          // Check if execution allowed
cb_on_success(cb)                           // Record success
cb_on_failure(cb)                           // Record failure + snapshot
cb_execute_with_recovery(cb, func_ptr)      // Protected execution
```

**Integration Flow:**
```
1. cb_execute_with_recovery(cb, compile_unit)
2. Create checkpoint before execution
3. Execute unit
4. If crash → signal_handler_segfault() triggered
5. cb_on_failure() → state = OPEN, create snapshot
6. sys_mem_restore(checkpoint)
7. Freeze child processes (prevent concurrent corruption)
8. Trickster eval: "elapsed_time > timeout && depth < max"
9. If TRUE → retry (state = HALF_OPEN)
10. If 3 successes → state = CLOSED
11. Unfreeze child processes
```

---

## Memory Architecture Integration

### Swap Systems (8 Sandboxes, 4 Snapshots)

**Sandbox (8 × 64MB):**
- Short-term, per-fragment compilation
- Isolated execution environments
- Quick checkpoint/rollback

**Snapshot (4 × 128MB):**
- Long-term, per-shard checkpoints
- Circuit breaker state preservation
- Recovery points

**Usage Pattern:**
```
Fragment 0 → Sandbox 0 → compile → checkpoint
Fragment 1 → Sandbox 1 → compile → checkpoint
...
Fragment 7 → Sandbox 7 → compile → checkpoint

Merge all sandboxes → Shard (Snapshot 0)

If Fragment 3 crashes:
  - Restore Sandbox 3 checkpoint
  - Retry Fragment 3
  - Other Fragments unaffected
```

---

## Example: Type Unknown Error Recovery

**Scenario:** Unit 1 has `TYPE_UNKNOWN` error in types.fox

**Without Fault Tolerance:**
```
Compile entire compiler → Type Unknown error
→ CRASH
→ Rebuild entire codebase
→ No information about which unit failed
```

**With Fault Tolerance:**
```
1. Compile Unit 1 (types.fox)
2. Error: TYPE_UNKNOWN detected
3. Signal handler catches error
4. unit_close(1) → isolate Unit 1
5. Circuit breaker: state = OPEN for Unit 1
6. Continue compiling Units 2-7 (unaffected!)
7. Log: "Unit 1 has TYPE_UNKNOWN at line 42"
8. Fix Unit 1 only
9. Recompile Unit 1 (not entire codebase)
10. Circuit breaker: 3 successes → state = CLOSED
11. All units working!
```

**Result:**
- ✅ Other units continue
- ✅ Fast incremental fixing
- ✅ Precise error location
- ✅ No "membongkar pasang codebase"

---

## Integration Test

**File:** `examples/test_integrated_recovery.fox`

**Tests:**
1. **Unit Isolation**
   - Close unit 1
   - Verify units 2-3 can execute
   - Verify unit 1 cannot execute

2. **Trickster Determinism**
   - Evaluate: `failure_count < threshold`
   - Evaluate: `elapsed_time > timeout`
   - Combined: `expr1 AND expr2`

3. **Circuit Breaker State Machine**
   - Initial state: CLOSED
   - After 3 failures: OPEN
   - After timeout: HALF_OPEN
   - After 3 successes: CLOSED

4. **Signal Handler Init**
   - Register SIGSEGV, SIGABRT handlers
   - Verify global crash state initialized

---

## Benefits

### 1. **Security** (Isolation)
- Process-level isolation per fragment
- Direct syscalls (no libc attack surface)
- Sandboxed execution prevents cross-contamination

### 2. **Determinism** (Trickster)
- Consistent AST generation across platforms
- Reproducible builds
- Predictable error handling

### 3. **Robustness** (Boolean/Unit)
- Granular fault isolation
- Incremental recovery
- No cascade failures

### 4. **Performance** (Circuit Breaker)
- Fast-fail for known issues
- Automatic recovery attempt
- Resource protection (max recursion)

---

## Future Enhancements

### Phase 2: AST-Level Fragmentation
- Parse entire file → AST
- Fragment by function (not by line)
- Compile each function independently
- Smart merge with dependency resolution

### Phase 3: Daemon Built-in
- Migrate morph_cleaner.sh logic to lib/
- `cleanup_old_snapshots()` as native function
- Real-time memory management during compilation

### Phase 4: Multi-Platform
- Test on BSD, macOS (kernel syscalls may differ)
- Ensure signal numbers consistent
- Validate deterministic behavior cross-platform

---

## File Locations

```
lib/
├── bool.fox                 # ID 200-209 (Boolean + Unit Isolation)
├── circuit_breaker.fox      # ID 210-217 (Circuit Breaker)
├── trickster.fox            # ID 220-225 (Expression Evaluator)
└── kernel/
    └── signals.fox          # ID 500-513 (Signal Handling)

examples/
├── test_integrated_recovery.fox      # Integration test
├── test_checkpoint_pure.fox          # Memory checkpoint test
├── test_runtime_simple.fox           # Basic runtime test
└── ... (other tests)

tools/
├── compile_fragmented.sh    # Batch compilation script
├── merge_deterministic.sh   # Deterministic merge algorithm
└── split_smart.sh          # Smart boundary splitting

docs/
├── FAULT_TOLERANCE_ARCHITECTURE.md  # This file
├── LAPORAN_SESSION_JULES.md         # Jules refactoring log
└── MORPH_SELF_HOSTING.md            # Self-hosting structure
```

---

## ID Registry

```fox
# Boolean Utilities and Unit Isolation (200-209)
Daftar "lib/bool.fox" = 200-209

# Circuit Breaker Pattern (210-219)
Daftar "lib/circuit_breaker.fox" = 210-217

# Trickster Expression Evaluator (220-239)
Daftar "lib/trickster.fox" = 220-225

# Kernel Library - Signal Handling (500-519)
Daftar "lib/kernel/signals.fox" = 500-513
```

---

## Status

**Implemented:** ✅ All 4 components (4→3→1→2)
**Tested:** ⏳ Awaiting helper compilation
**Next Steps:**
1. Compile helper files (parser_helpers_*)
2. Test `test_integrated_recovery.fox`
3. Validate unit isolation with real Type Unknown error
4. Document results

---

**Author:** Claude (Session 2026-01-04)
**Reviewed by:** User (VzoelFox)
**License:** MIT (same as Morph project)
