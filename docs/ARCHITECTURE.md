# Arsitektur Compiler Morph

Dokumen ini menjelaskan desain internal dan keputusan arsitektural di balik compiler Morph (v1.0+).

## Filosofi Desain
1.  **Zero-Abstraction:** Tidak ada Virtual Machine (VM). Kode Morph dikompilasi langsung menjadi Assembly x86_64 murni.
2.  **Freestanding Kernel:** Output binary tidak bergantung pada `libc` atau runtime OS standar. Semua syscall (Memory, I/O) ditangani oleh "Kernel" assembly internal yang disuntikkan oleh compiler.
3.  **Granular Import:** Sistem modulasi berbasis ID, bukan file, untuk meminimalkan ukuran kode dan dependensi.

## Komponen Utama

### 1. Bootstrap Compiler (`bootstrap/morph.sh`)
*   Ditulis dalam **Bash**.
*   **Parser (`parser.sh`):** Line-based parsing sederhana. Menggunakan Regex bash untuk tokenizing. Mengelola Symbol Table (`STRUCT_OFFSETS`, `VAR_TYPE_MAP`).
*   **Codegen (`codegen.sh`):** Menghasilkan string NASM Assembly. Berisi definisi "Kernel" (`init_codegen`).

### 2. Self-Hosted Compiler (`apps/compiler/src/main.fox`)
*   Ditulis dalam **Morph** itu sendiri.
*   **Struktur:**
    *   `src/main.fox`: Entry point dan logika Parser utama (Control Flow, Var Parsing, Codegen).
    *   `pkg/utils.fox`: Paket internal yang berisi **JSON Parser** (High-Level) dan **Tagger Registry**.
*   **Keamanan:** Logika parser internal (seperti JSON) diimplementasikan menggunakan abstraksi tingkat tinggi (`str_get`, `str_slice`) dan menghindari assembly mentah untuk membatasi akses kernel yang tidak perlu.

### 3. Kernel Assembly (Runtime)
Setiap binary Morph yang dihasilkan mengandung header assembly (`_start`) yang melakukan:
*   **Memory Init:** Menginisialisasi Heap V2 menggunakan `sys_mmap` (256MB Chunk).
*   **Arg Injection:** Mengambil `argc` dan `argv` dari stack OS dan menyimpannya ke variabel global `var_global_argc` dan `var_global_argv` di section `.bss`.
*   **Syscall Wrappers:** Menyediakan fungsi pembantu seperti `sys_alloc`, `sys_read_fd`, `sys_panic`.

### 4. Memory Model V2
*   **Dynamic Heap:** Menggunakan `mmap` (syscall 9) untuk meminta blok memori besar dari OS.
*   **Bump Allocator:** `sys_alloc` hanya memajukan pointer (`heap_current_ptr`). Sangat cepat, tapi tidak ada `free` individual (hanya reset via `sys_mem_rollback` atau `sys_munmap` seluruh chunk).
*   **Struct Layout:** Field struct disejajarkan (aligned) 8-byte (64-bit).

### 5. Sistem Granular Import (Tagger)
*   **Registry:** Dipusatkan di `apps/compiler/pkg/utils.fox` untuk self-host compiler.
*   **Proses Import:**
    1.  `ambil "filepath"` (huruf kecil): Include source file lokal.
    2.  `Ambil ID, ID` (huruf besar): Import granular berdasarkan ID dari registry.

### 6. Tooling Ekosistem
*   **Morph Runner (`./morph`)**: Script wrapper yang menangani kompilasi lokal dan eksekusi remote (VPS). Mendukung mode "Run" (seperti Python) dan "Build" (seperti Go build `to <file>`).
*   **Star Installer (`./star`)**: Package dan Configuration manager sederhana yang membaca file `.fall` (Key-Value) untuk menghasilkan konfigurasi `config.mk`.
*   **Test Runner (`./tmorph`)**: Otomatisasi pengujian untuk file examples dan tests.

## Roadmap Self-Hosting
Tujuan akhir adalah menggantikan `bootstrap/morph.sh` dengan `apps/compiler/src/main.fox`.
Status saat ini (Fase 3 Self-Host Parser):
*   `main.fox` mendukung parsing variabel (`var`), kontrol alur (`jika`, `lain`, `selama`), fungsi (`panggil`), dan aritmatika dasar (`+`, `-`, `*`).
*   JSON Parser telah di-porting ke `apps/compiler/pkg/utils.fox` dengan implementasi yang aman (no-asm).
*   Langkah selanjutnya: Implementasi parsing `struktur` dan ekspresi kompleks.
