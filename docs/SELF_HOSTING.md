# Morph Self-Hosting Phase

Fase ini menandai transisi besar dari "Bootstrap Compiler" (Shell Script) menuju "Self-Hosted Compiler" (ditulis dalam Morph).

## Visi
Menciptakan ekosistem di mana compiler Morph dapat mengompilasi dirinya sendiri. Ini membuktikan kematangan bahasa dan library yang telah dibangun.

## Struktur Direktori Baru

*   `apps/compiler/`: Source code compiler Morph masa depan (`morph.fox`).
*   `bootstrap/`: Compiler lama (Shell Script) yang digunakan untuk mengompilasi `apps/compiler/morph.fox` sampai compiler tersebut cukup stabil untuk mengambil alih.
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

## Library Pendukung Baru

*   **`lib/file_io.fox` (ID 318):**
    *   Fungsi `buffer_dari_file(filepath)`: Membuka file, membaca isinya ke dalam `MemoryBuffer`, dan menutup file.

*   **`lib/string_utils.fox` (ID 380-386):**
    *   Fungsi manipulasi string esensial untuk parsing teks: `str_split_lines`, `str_trim`, `str_starts_with`, `str_slice`.

## Milestone Saat Ini
- [x] CLI Runner (`./morph`) untuk workflow develop-run yang cepat.
- [x] Compiler Skeleton (`morph.fox`) yang bisa dikompilasi oleh bootstrap.
- [x] Compiler Skeleton bisa membaca file input dan argumen CLI.
- [ ] Implementasi Parser penuh di `morph.fox`.
- [ ] Implementasi Codegen penuh di `morph.fox`.
