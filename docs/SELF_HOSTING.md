# Morph Self-Hosting Phase

Fase ini menandai transisi besar dari "Bootstrap Compiler" (Shell Script) menuju "Self-Hosted Compiler" (ditulis dalam Morph).

## Visi
Menciptakan ekosistem di mana compiler Morph dapat mengompilasi dirinya sendiri. Ini membuktikan kematangan bahasa dan library yang telah dibangun.

## Struktur Direktori Baru

*   `apps/compiler/src/main.fox`: Source code compiler Morph self-hosted. Entry point utama yang menangani parsing dan code generation.
*   `apps/compiler/pkg/utils.fox`: Paket utilitas internal compiler, berisi JSON Parser (High-Level) dan registry library standar.
*   `bootstrap/`: Compiler lama (Shell Script) yang digunakan untuk mengompilasi `apps/compiler/src/main.fox` sampai compiler tersebut cukup stabil untuk mengambil alih.
*   `lib/`: Standard Library yang digunakan oleh kedua compiler (dan aplikasi user).

## Perubahan Kernel & Runtime (v1.0 Update)

Untuk mendukung compiler mandiri, Kernel Assembly (`codegen.sh`) telah ditingkatkan:

1.  **File I/O Syscalls:**
    *   Menambahkan `SYS_OPEN` (2) dan `SYS_CLOSE` (3).
    *   Wrapper `sys_read_fd` untuk membaca dari File Descriptor spesifik (bukan hanya stdin).

2.  **Argument Parsing (Global Injection):**
    *   Kernel `_start` sekarang secara otomatis menangkap `argc` (jumlah argumen) dan `argv` (array pointer argumen) dari stack OS.
    *   Nilai ini disuntikkan ke variabel global BSS: `var_global_argc` dan `var_global_argv`.
    *   Aplikasi Morph dapat mengaksesnya via `global_argc` dan `global_argv` tanpa perlu setup manual.

## Milestone & Status

### Fase 1: Infrastruktur & Bootstrap
- [x] CLI Runner (`./morph`) untuk workflow develop-run yang cepat.
- [x] Compiler Skeleton (`morph.fox`) yang bisa dikompilasi oleh bootstrap.
- [x] Compiler Skeleton bisa membaca file input dan argumen CLI.

### Fase 2: Self-Host Parser Implementation
- [x] **Refactoring Struktur**: Pemisahan `src` dan `pkg`, relokasi logika JSON.
- [x] **JSON Parser Self-Host**: Porting logika parsing JSON ke `pkg/utils.fox` menggunakan pendekatan aman (High-Level String Utils, No-ASM).
- [x] **Basic Variable Parsing**: Parsing `var x = 10` dan `var x = y`.
- [x] **Arithmetic Parsing**: Dukungan operasi dasar `+`, `-`, `*` dalam assignment.
- [x] **Control Flow**: Implementasi `jika`, `lain` (Else), dan `selama` (Looping) dengan stack label management.
- [x] **Function Calls**: Implementasi `panggil func(arg)`.

### Fase 3: Menuju Full Self-Hosting (Next Steps)
- [ ] **Struct Parsing**: Implementasi keyword `struktur` dan akses member (`var.field`).
- [ ] **Complex Expressions**: Dukungan ekspresi matematika/logika yang lebih kompleks (nested parentheses, precedence).
- [ ] **Else If Support**: Implementasi penuh untuk `lain_jika`.
- [ ] **String Literals**: Dukungan escape character dalam string.
- [ ] **Optimized Codegen**: Manajemen register yang lebih efisien (bukan hanya stack/rax).

## Catatan Teknis (Sesi Ini)
*   **Keamanan**: JSON parser self-hosted dibatasi untuk tidak menggunakan instruksi assembler mentah (`asm_mulai`) untuk logika parsing, hanya untuk return value convention. Ini memastikan keamanan dan portabilitas logika.
*   **Konvensi Import**: `ambil "path/to/file"` digunakan untuk include file source, sedangkan `Ambil ID` digunakan untuk import granular dari registry.
*   **Memory Safety**: Perbaikan pada `format_int` (Standard Library) untuk mencegah memory leak dan memastikan pointer yang dikembalikan valid (awal buffer).
