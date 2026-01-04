# Laporan Sesi Pengembangan - Refactoring & Stabilisasi Compiler Self-Hosted

**Tanggal:** 3 Januari 2025
**Kontributor:** Jules (AI Assistant)

## Ringkasan Eksekutif
Sesi ini difokuskan pada upaya stabilisasi compiler self-hosted (`apps/compiler/src/main.fox`) agar dapat dikompilasi oleh bootstrap compiler dan dijalankan dengan sukses. Upaya utama meliputi perbaikan bug kritis pada bootstrap parser, implementasi fungsi standar yang hilang, dan refactoring besar-besaran struktur kode compiler self-hosted untuk mengatasi batasan memori/stack pada bootstrap compiler.

## Perubahan Dilakukan

### 1. Refactoring Struktur Compiler Self-Hosted
Untuk mengatasi masalah stabilitas (crash) saat kompilasi file besar, `apps/compiler/src/main.fox` dipecah menjadi beberapa modul terpisah:

*   **`apps/compiler/src/main.fox`**: Entry point utama yang ringkas. Mengatur urutan inisialisasi dan memanggil parser utama.
*   **`apps/compiler/src/globals.fox`**: Deklarasi variabel global, buffer output, dan alokasi memori awal (`vec_create`, `map_create`). Mengimpor library standar via `Ambil`.
*   **`apps/compiler/src/constants.fox`**: Inisialisasi konstanta string assembler (`s_mov_rax`, dll). **Penting:** Dipisahkan dari `globals.fox` karena inisialisasi string dalam jumlah besar pada satu fungsi menyebabkan crash runtime (kemungkinan batasan ukuran fungsi atau stack pada bootstrap).
*   **`apps/compiler/src/codegen.fox`**: Utilitas code generation dasar (`emit`).
*   **`apps/compiler/src/parser.fox`**: Logika parsing utama (`parse_source_lines`) yang dipindahkan dari `main.fox`.
*   **`apps/compiler/src/types.fox`**: Definisi sistem tipe, struct (`Token`, `ExprNode`), dan konstanta tipe.

### 2. Bug Fixes

#### A. Bootstrap Parser (`bootstrap/lib/parser.sh`)
*   **Masalah:** Argumen fungsi yang mengandung spasi atau tanda kutip rusak karena penggunaan `xargs`.
*   **Fix:** Mengganti pipe `xargs` dengan `sed` untuk trimming whitespace agar integritas string literal terjaga.

#### B. Standard Library (`lib/string_utils.fox`)
*   **Masalah:** Fungsi `str_to_int` dan `str_index_of` hilang namun dibutuhkan oleh compiler.
*   **Fix:** Mengimplementasikan kedua fungsi tersebut (ID 390, 391) dan mendaftarkannya di `utils.fox` dan `tagger.fox`.

#### C. Type System (`apps/compiler/src/types.fox`)
*   **Masalah:** Penggunaan konstanta `const` (seperti `TYPE_INT`) di dalam blok `asm_mulai` menyebabkan error "symbol not defined". Bootstrap compiler memperlakukan `const` sebagai variabel global, bukan literal assembler.
*   **Fix:** Mengganti penggunaan konstanta di dalam blok ASM dengan literal integer langsung.

#### D. Import Ordering (`apps/compiler/src/main.fox`)
*   **Masalah:** `globals.fox` menggunakan `Ambil` (butuh `ID_MAP`), tetapi `ID_MAP` baru diisi oleh `utils.fox` (via `Daftar`). Jika `globals.fox` di-load sebelum `utils.fox`, library tidak ter-load.
*   **Fix:** Memastikan `apps/compiler/pkg/utils.fox` di-load paling awal di `main.fox`.

### 3. Fitur Baru
*   Menambahkan definisi struct `Token` dan `ExprNode` (untuk persiapan Trickster/Expression Parser) serta `Unit` dan `Shard` (untuk arsitektur Absolute AST) di `types.fox`.

## Gap & Hutang Teknis (Technical Debt)

### 1. Crash Runtime "Silent"
Compiler self-hosted berhasil dikompilasi dan dijalankan (mencetak log debug inisialisasi dan parsing awal), namun berhenti mendadak tanpa pesan "Success!".
*   **Dugaan:** Masih ada sisa masalah memori atau stack overflow di tahap akhir code generation atau penulisan file output.
*   **Status:** Inisialisasi global sudah stabil setelah pemisahan `constants.fox`, namun eksekusi penuh masih belum 100% tuntas.

### 2. Output Assembly Korup
Pada percobaan sebelumnya, file `output.asm` yang dihasilkan mengandung string sampah ("Hello from Library!") yang tidak seharusnya ada. Ini mengindikasikan buffer output mungkin tidak bersih atau ada pointer yang salah sasaran.

### 3. Batasan Bootstrap Compiler
Bootstrap compiler (Bash) memiliki batasan yang tidak terdokumentasi dengan baik terkait ukuran fungsi dan jumlah literal string, yang memaksa pemecahan `init_globals`.

### 4. Implementasi `const`
Keyword `const` pada bootstrap compiler sebenarnya membuat variabel global (`var`), bukan konstanta compile-time atau assembler macros (`equ`). Ini membingungkan saat digunakan di blok inline assembly.

### 5. Expression Parsing (Trickster)
Meskipun struktur data (`ExprNode`) sudah ada, logika parsing ekspresi kompleks belum diimplementasikan di sisi self-hosted.

## Rekomendasi Langkah Selanjutnya
1.  **Debugging Code Generation:** Investigasi mengapa compiler berhenti setelah parsing (periksa `emit` dan `sys_write`).
2.  **Implementasi Trickster:** Mulai porting logika parsing ekspresi ke `parser.fox` menggunakan struct baru.
3.  **Unit Testing:** Buat test case lebih kecil untuk setiap modul compiler self-hosted.
