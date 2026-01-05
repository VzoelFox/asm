# Dokumentasi Morph (Bootstrap Phase)

Proyek ini bertujuan untuk membangun bahasa pemrograman "Morph" dari nol, dimulai dengan *bootstrap compiler* sederhana berbasis Shell Script yang menghasilkan Assembly x86_64 murni (freestanding).

## Struktur Proyek

```
.
├── bootstrap/          # Source code compiler
│   ├── morph.sh        # Entry point compiler
│   └── lib/            # Modul logika compiler
│       ├── codegen.sh  # Generator Assembly
│       └── parser.sh   # Parser Syntax Morph
├── examples/           # Contoh kode Morph
│   └── hello.fox
├── docs/               # Dokumentasi tambahan
├── Makefile            # Otomatisasi build & run
├── config.mk           # Konfigurasi environment (VPS)
└── README.md           # Dokumentasi utama
```

## Prasyarat

- **Lokal**: `sshpass`, `make`, `bash`.
- **Remote (VPS)**: `nasm`, `ld`.

## Alur Kerja "Make Modular"

Kami menggunakan `Makefile` untuk mengotomatisasi seluruh proses pengembangan, mengatasi keterbatasan memori sandbox dengan melakukan *remote build*.

### Perintah Tersedia

1. **Compile & Run (All-in-One)**
   Jalankan perintah ini untuk melakukan kompilasi lokal, upload, build remote, dan eksekusi:
   ```bash
   make all
   ```

2. **Langkah Demi Langkah**
   - `make compile`: Mengubah `.fox` menjadi `.asm` (Lokal).
   - `make deploy`: Mengirim file `.asm` ke VPS.
   - `make build`: Merakit (`nasm`) dan menautkan (`ld`) binary di VPS.
   - `make run`: Menjalankan binary di VPS.
   - `make clean`: Membersihkan file temporary.

## Konfigurasi

File `config.mk` berisi detail koneksi VPS. Secara default telah dikonfigurasi untuk environment pengembangan saat ini.

## Bootstrap Compiler (`bootstrap/morph.sh`)

Compiler ini ditulis murni dalam Bash untuk portabilitas maksimal di tahap awal.
- **Input**: Kode Morph (`.fox`).
- **Output**: Assembly x86_64 (NASM).
- **Modul**:
  - `parser.sh`: Membaca baris kode dan menentukan aksi.
  - `codegen.sh`: Menghasilkan string assembly yang sesuai.
