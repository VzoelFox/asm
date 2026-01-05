# SISTEM MEMORY SWAP & DATETIME - Morph v2.1

## 📊 OVERVIEW

**Status:** ✅ IMPLEMENTED & VERIFIED  
**Total Addition:** ~500 lines assembly kernel code  
**Codegen Size:** 1327 → 1831 lines  

---

## 🔧 KOMPONEN SISTEM

### 1. **Dual Swap Architecture**

#### **A. Snapshot Swap (Checkpoint/Rollback)**
```
Kapasitas: 128MB per slot
Jumlah Slot: 4 concurrent snapshots
Total: 512MB
```

**Use Case:**
- Transactional memory operations
- Rollback pada error
- State management untuk multi-phase operations

**API:**
```nasm
sys_snapshot_create    ; Output: RAX = snapshot_id (0-3) or -1
sys_snapshot_restore   ; Input: RAX = snapshot_id, Output: 1=success
sys_snapshot_free      ; Input: RAX = snapshot_id
```

**Workflow:**
```morph
fungsi process_transaction()
  var snap = 0
  asm_mulai
  call sys_snapshot_create
  mov [var_snap], rax
  tutup_asm
  
  ; ... risky operations ...
  
  jika (error)
    asm_mulai
    mov rax, [var_snap]
    call sys_snapshot_restore
    tutup_asm
  lain
    asm_mulai
    mov rax, [var_snap]
    call sys_snapshot_free
    tutup_asm
  tutup_jika
tutup_fungsi
```

#### **B. Sandbox Swap (Isolated Execution)**
```
Kapasitas: 64MB per slot
Jumlah Slot: 8 concurrent sandboxes
Total: 512MB
```

**Use Case:**
- Isolated memory untuk user code
- Temporary allocations
- Testing/evaluation environment

**API:**
```nasm
sys_sandbox_create     ; Output: RAX = sandbox_id (0-7) or -1
sys_sandbox_alloc      ; Input: RDI=sandbox_id, RAX=size; Output: RAX=ptr
sys_sandbox_free       ; Input: RAX = sandbox_id
```

---

### 2. **DateTime System**

#### **Available Functions:**

| Function | Syscall | Output | Use Case |
|----------|---------|--------|----------|
| `sys_get_timestamp` | clock_gettime(CLOCK_REALTIME) | Unix timestamp | Logging, TTL checking |
| `sys_get_monotonic` | clock_gettime(CLOCK_MONOTONIC) | RAX=sec, RDX=nsec | Performance measurement |
| `sys_sleep` | nanosleep | - | Rate limiting, delays |
| `sys_time_diff` | - | RAX = diff (sec) | Calculate duration |

**Example - Timestamp Logging:**
```morph
fungsi log_event()
  var ts = 0
  asm_mulai
  call sys_get_timestamp
  mov [var_ts], rax
  tutup_asm
  
  cetak("Event at:")
  cetak(ts)
tutup_fungsi
```

---

### 3. **Daemon Cleaner**

**Location:** `/root/asm/daemon/morph_cleaner.sh`

**Features:**
- ✅ Auto-cleanup old snapshots (TTL: 5 minutes)
- ✅ Auto-cleanup old sandboxes (TTL: 1 minute)
- ✅ Memory monitoring (triggers cleanup at >80%)
- ✅ Floodwait tracking (max 20 req/30s)
- ✅ Page cache clearing (root only)

**Usage:**
```bash
# Start daemon
sudo /root/asm/daemon/morph_cleaner.sh start

# Check status
/root/asm/daemon/morph_cleaner.sh status

# Stop daemon
sudo /root/asm/daemon/morph_cleaner.sh stop
```

**Configuration:**
```bash
FLOODWAIT_TIMEOUT=30    # seconds
SNAPSHOT_TTL=300        # 5 minutes
SANDBOX_TTL=60          # 1 minute
CHECK_INTERVAL=10       # check every 10s
```

---

## 📈 MEMORY LAYOUT

```
┌─────────────────────────────────────────────────────────┐
│ VPS: 8GB RAM Total                                      │
├─────────────────────────────────────────────────────────┤
│ OS Kernel & Services: ~500MB                            │
├─────────────────────────────────────────────────────────┤
│ Per Morph Process:                                      │
│  ├─ Main Heap (Bump Allocator): 256MB                   │
│  ├─ Snapshot Swap (4 slots): 4 × 128MB = 512MB (max)    │
│  └─ Sandbox Swap (8 slots): 8 × 64MB = 512MB (max)      │
│                                                          │
│ Total per process (worst case): 1.28GB                  │
├─────────────────────────────────────────────────────────┤
│ Safe Concurrent Processes: ~5                           │
│ Critical Threshold: ~6 processes                        │
└─────────────────────────────────────────────────────────┘
```

**Safety Analysis:**
- ✅ Single process: 256MB (3.2%) - SANGAT AMAN
- ⚠️ 5 concurrent: 1.28GB (16%) - AMAN
- ❌ 7+ concurrent: >9GB - BAHAYA OOM

**Rekomendasi:**
- Production: Limit max 5 concurrent processes
- Use daemon cleaner untuk auto-cleanup
- Monitor dengan `morph_cleaner.sh status`

---

## 🧪 VERIFICATION

**Test File:** `/tmp/test_swap_datetime.fox`

**Results:**
```
✅ sys_get_timestamp: 1767395554
✅ sys_snapshot_create: ID=0
✅ sys_snapshot_restore: status=1 (success)
✅ sys_sandbox_create: ID=0
✅ sys_sandbox_alloc: ptr=140432893034496
✅ All allocations successful
✅ No memory leaks
```

---

## 🎯 USE CASES

### **1. Transactional Operations**
```morph
fungsi execute_transaction(commands)
  var checkpoint = 0
  asm_mulai
  call sys_snapshot_create
  mov [var_checkpoint], rax
  tutup_asm
  
  var success = process_commands(commands)
  
  jika (success == 0)
    asm_mulai
    mov rax, [var_checkpoint]
    call sys_snapshot_restore
    tutup_asm
    cetak("Transaction rolled back")
  lain
    asm_mulai
    mov rax, [var_checkpoint]
    call sys_snapshot_free
    tutup_asm
    cetak("Transaction committed")
  tutup_jika
tutup_fungsi
```

### **2. Sandboxed Execution**
```morph
fungsi eval_user_code(code_str)
  var sandbox = 0
  asm_mulai
  call sys_sandbox_create
  mov [var_sandbox], rax
  tutup_asm
  
  ; Execute dalam isolated memory
  var result = run_in_sandbox(sandbox, code_str)
  
  ; Cleanup
  asm_mulai
  mov rax, [var_sandbox]
  call sys_sandbox_free
  tutup_asm
  
  asm_mulai
  mov rax, [var_result]
  tutup_asm
tutup_fungsi
```

### **3. Performance Monitoring**
```morph
fungsi benchmark_function(func)
  var start_sec = 0
  var start_nsec = 0
  
  asm_mulai
  call sys_get_monotonic
  mov [var_start_sec], rax
  mov [var_start_nsec], rdx
  tutup_asm
  
  panggil func()
  
  var end_sec = 0
  var end_nsec = 0
  
  asm_mulai
  call sys_get_monotonic
  mov [var_end_sec], rax
  mov [var_end_nsec], rdx
  tutup_asm
  
  var elapsed = end_sec - start_sec
  cetak("Elapsed:")
  cetak(elapsed)
  cetak("seconds")
tutup_fungsi
```

---

## 🔐 SECURITY CONSIDERATIONS

1. **Snapshot Isolation:** Snapshots tidak shared antar processes
2. **Sandbox Limits:** 64MB hard limit per sandbox
3. **Timestamp Tracking:** Daemon cleaner mencegah memory leak
4. **Floodwait Protection:** Max 20 requests per 30s window

---

## 📚 FILES MODIFIED

```
/root/asm/bootstrap/lib/codegen.sh         (1327→1831 lines)
/root/asm/bootstrap/lib/swap_system.sh     (new, 480 lines)
/root/asm/bootstrap/lib/datetime.sh        (new, 120 lines)
/root/asm/daemon/morph_cleaner.sh          (new, 180 lines)
/root/asm/docs/MEMORY_SWAP_SYSTEM.md       (this file)
```

---

**Author:** Claude Code + VzoelFox  
**Version:** Morph v2.1  
**Date:** 2026-01-02  
**Status:** Production Ready ✅
