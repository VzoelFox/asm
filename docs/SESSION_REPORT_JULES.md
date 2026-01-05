# Laporan Sesi Refactoring & Stabilisasi Compiler Morph
**Engineer:** Jules
**Tanggal:** 2026-01-05 (Session Log)

## Ringkasan Eksekutif
Sesi ini berfokus pada pembersihan "hutang teknis" (technical debt) yang ditinggalkan oleh iterasi sebelumnya, stabilisasi *bootstrap compiler*, dan modernisasi arsitektur *self-hosted compiler* agar lebih standar dan mudah dipelihara.

**Status Akhir:**
*   **Compiler:** Berhasil dikompilasi (bootstrap), berjalan di VPS, membaca input, dan menghasilkan output assembly.
*   **Runtime:** Stabil (Crash saat inisialisasi telah diperbaiki).
*   **Struktur:** Bersih (File-based imports, tanpa ID markers).
*   **Memori:** Dinamis (Alokasi 20% RAM Host).

---

## Detail Perubahan

### 1. Refactoring Sistem Import (Modular ID -> File-Based)
Sistem impor berbasis ID (warisan Kiro AI) yang rumit dan rentan kesalahan telah dihapus total.

*   **Tindakan:**
    *   Mengganti sintaks `Ambil <ID>` menjadi `ambil "filepath"` di seluruh source code (`apps/compiler/src/main.fox`, `parser.fox`, `exprs.fox`).
    *   Menghapus file `indeks.fox` (Global Registry) yang menjadi titik kegagalan sentral.
    *   Membersihkan penanda `### <ID>` dari seluruh file source code `.fox`.
*   **Dampak:** Kode kini lebih mudah dibaca ("Readable for AI") dan dependensi antar-file menjadi eksplisit.

### 2. Perbaikan Critical Bugs (Bootstrap Kernel)
Ditemukan dan diperbaiki sejumlah bug kritis pada infrastruktur dasar (*bootstrap compiler* dalam Bash):

*   **Parser (`bootstrap/lib/parser.sh`):**
    *   **Label Collision:** Menambahkan `GLOBAL_STR_CTR` untuk mencegah duplikasi label string (`str_arg_...`) saat mengimpor banyak file. Sebelumnya label bertabrakan karena reset baris per file.
    *   **Range Import:** Memperbaiki regex `Ambil` agar mendukung rentang (misal `380-391`) - *Legacy fix sebelum migrasi total*.
*   **Codegen (`bootstrap/lib/codegen.sh`):**
    *   **Data Emission:** Mengaktifkan kembali fungsi `emit_raw_data_fixed` yang sebelumnya dikomentari (disabled), yang menyebabkan string literal tidak terdefinisi (`undefined symbol`).

### 3. Stabilisasi Runtime & Memory System
Mengatasi masalah *Segmentation Fault* dan skalabilitas memori.

*   **Dynamic Heap Allocation:**
    *   Memodifikasi `codegen.sh` untuk mendeteksi total RAM host secara dinamis via syscall `sysinfo`.
    *   Ukuran Heap kini di-set ke **20% Total RAM** (dengan fallback 64MB). Ini memungkinkan testing di Sandbox (RAM kecil) dan produksi di VPS (RAM besar) tanpa ubah kode.
*   **Fix `init_constants` Crash:**
    *   Memecah fungsi raksasa `init_constants` menjadi 3 bagian (`init_constants_1`, `2`, `3`). Ukuran fungsi yang berlebihan sebelumnya menyebabkan korupsi stack pada output bootstrap.
*   **Cleaner Daemon (`morph_cleaner.sh`):**
    *   Menulis ulang script menjadi sederhana dan jujur: hanya memantau penggunaan RAM dan membersihkan *page cache* jika >80%. Menghapus fitur-fitur fiktif/rusak.

### 4. Perbaikan Pustaka Standar (`lib/`)
*   **Symbol Conflicts:** Mengubah nama fungsi sistem di `lib/builtins.fox` (misal `sys_read` -> `_override_sys_read`) untuk mencegah konflik linking dengan helper bawaan bootstrap.
*   **Logic Fixes:**
    *   Memperbaiki sintaks loop `selama (1)` menjadi `selama (1 == 1)` agar kompatibel dengan parser bootstrap.
    *   Memperbaiki passing pointer newline pada `sys_write`.

### 5. Cleanup (Kebersihan Repositori)
*   Menghapus direktori `tools/` berisi skrip rusak (`morph_robot`).
*   Menghapus dokumentasi usang dan menyesatkan di `docs/` dan root.
*   Menghapus file sampah sementara hasil debugging.

---

## Langkah Selanjutnya (Rekomendasi)
1.  **Debugging Output Assembly:** Meskipun compiler berjalan, output `output.asm` yang dihasilkan masih mengandung label sampah (`len_msg_\x88...`) dan string aneh. Logika *string concatenation* atau *label generation* di level `morph` (self-hosted) perlu diperiksa.
2.  **Self-Hosting:** Mencoba mengompilasi `apps/compiler/src/main.fox` menggunakan *compiler yang baru dihasilkan* (bukan bootstrap).
