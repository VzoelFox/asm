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

### 2. Kernel Assembly (Runtime)
Setiap binary Morph yang dihasilkan mengandung header assembly (`_start`) yang melakukan:
*   **Memory Init:** Menginisialisasi Heap V2 menggunakan `sys_mmap` (256MB Chunk).
*   **Arg Injection:** Mengambil `argc` dan `argv` dari stack OS dan menyimpannya ke variabel global `var_global_argc` dan `var_global_argv` di section `.bss`.
*   **Syscall Wrappers:** Menyediakan fungsi pembantu seperti `sys_alloc`, `sys_read_fd`, `sys_panic`.

### 3. Memory Model V2
*   **Dynamic Heap:** Menggunakan `mmap` (syscall 9) untuk meminta blok memori besar dari OS.
*   **Bump Allocator:** `sys_alloc` hanya memajukan pointer (`heap_current_ptr`). Sangat cepat, tapi tidak ada `free` individual (hanya reset via `sys_mem_rollback` atau `sys_munmap` seluruh chunk).
*   **Struct Layout:** Field struct disejajarkan (aligned) 8-byte (64-bit).

### 4. Sistem Granular Import (Tagger)
*   **Registry (`tagger.fox`):** File sentral yang memetakan Range ID ke Filepath.
    ```morph
    Daftar "lib/math.fox" = 100-105
    ```
*   **Proses Import:**
    1.  `indeks "tagger.fox"`: Parser membaca registry dan mengisi `ID_MAP`.
    2.  `Ambil 100`: Parser mencari file untuk ID 100, lalu hanya mengekstrak blok kode di antara `### 100` dan marker berikutnya.

## Roadmap Self-Hosting
Tujuan akhir adalah menggantikan `bootstrap/morph.sh` dengan `apps/compiler/morph.fox`.
Status saat ini:
*   `morph.fox` dapat membaca file input dan memecahnya menjadi baris-baris (Lexer dasar).
*   Library pendukung (`File I/O`, `String Utils`) sudah siap.
*   Langkah selanjutnya: Porting logika parsing (Regex/String matching) ke Morph.
