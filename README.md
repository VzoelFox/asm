# Morph Language Project

Ini adalah repositori pengembangan bahasa pemrograman **Morph**.

Proyek ini telah memasuki fase **Self-Hosting**, di mana compiler Morph mulai ditulis ulang menggunakan bahasa Morph itu sendiri (`apps/compiler/morph.fox`), dibootstrap oleh compiler shell script (`bootstrap/morph.sh`).

## Status: Self-Hosting (Fase 3 Awal)
*   **Kernel:** x86_64 Assembly (Freestanding, no libc).
*   **Bootstrap Compiler:** Shell Script (Bash).
*   **Self-Hosted Compiler:** Morph (WIP, mampu membaca source file dan parsing dasar).
*   **Standard Library:** Buffer, Hashmap, Vector, JSON, File I/O, String Utils.

## Quick Start (CLI Runner)

Gunakan script runner `./morph` untuk pengalaman pengembangan modern (seperti `python` atau `go run`):

1. **Setup Konfigurasi:**
   Salin `config.mk.example` ke `config.mk` dan isi kredensial VPS (karena kompilasi assembly dilakukan remote).

2. **Jalankan Kode:**
   ```bash
   ./morph examples/hello.fox
   ```
   Script ini akan otomatis:
   *   Mengompilasi kode lokal (via bootstrap).
   *   Mengirim Assembly ke VPS.
   *   Merakit (`nasm`) dan Link (`ld`) di VPS.
   *   Menjalankan binary dan menampilkan outputnya.

## Dokumentasi

*   **[Manual Bahasa & Library](docs/LANGUAGE_MANUAL.md)**: Referensi lengkap sintaks dan library.
*   **[Arsitektur & Kernel](docs/ARCHITECTURE.md)**: Detail internal compiler, kernel, dan manajemen memori.
*   **[Self-Hosting Roadmap](docs/SELF_HOSTING.md)**: Detail transisi dari Bash ke Morph.
