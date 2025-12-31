# Morph Fase 1: Bootstrap & Fondasi Assembly

Fase ini menandai keberhasilan pembuatan *bootstrap compiler* untuk bahasa pemrograman Morph. Compiler ini ditulis menggunakan **Shell Script** (Bash) dan menghasilkan kode **Assembly x86_64** yang berjalan secara *freestanding* (tanpa libc).

## Pencapaian Fitur

### 1. Struktur Program
Morph menggunakan struktur berbasis fungsi dengan entry point `mulai`.
```ruby
fungsi mulai()
  ...
tutup_fungsi
```

### 2. Output (Cetak)
Mendukung pencetakan string dan integer (termasuk hasil ekspresi).
```ruby
cetak("Halo Dunia")
cetak(100 + 50)
```

### 3. Variabel
Deklarasi dan penggunaan variabel integer 64-bit.
```ruby
var x = 10
var y = x * 2
cetak(y)
```

### 4. Percabangan (Branching)
Logika `jika` dengan operator pembanding lengkap (`==`, `!=`, `<`, `>`, `<=`, `>=`).
```ruby
jika (x < y)
  cetak("x lebih kecil")
tutup_jika
```

### 5. Perulangan (Looping)
Loop `selama` (while) dengan dukungan manipulasi counter.
```ruby
selama (i < 5)
  i = i + 1
tutup_selama
```

### 6. Fungsi & Pemanggilan
Definisi fungsi dengan parameter dan pemanggilan eksplisit.
```ruby
fungsi tambah(a, b)
  var hasil = a + b
  cetak(hasil)
tutup_fungsi

fungsi mulai()
  panggil tambah(10, 20)
tutup_fungsi
```

### 7. Manajemen Memori & Input (V2 Lite)
Implementasi awal sistem memori dinamis dan input/output.
- **Arena Allocator**: Alokasi memori cepat (bump pointer) di atas heap statis (1MB).
- **Input (`baca`)**: Membaca input dari stdin ke buffer heap.
- **Output String Pointer (`cetak_str`)**: Mencetak string dari pointer memori (mendukung hasil input).

```ruby
var nama = baca(32)  # Alokasi 32 bytes & baca stdin
cetak_str(nama)      # Cetak isi buffer
```

### 8. Manajemen State (Low-Level)
Fitur untuk berinteraksi langsung dengan register CPU dan stack.
- **Inline Assembly**: `asm_mulai ... tutup_asm`
- **Snapshot/Restore**: `simpan` (Push All Regs) dan `kembalikan` (Pop All Regs) untuk rollback state register.

## Arsitektur Compiler

- **Parser (`parser.sh`)**: Membaca kode sumber baris per baris menggunakan Regex dan memanggil fungsi codegen.
- **Codegen (`codegen.sh`)**: Menghasilkan instruksi NASM x86_64.
  - Menggunakan **Arena Allocator** sederhana untuk manajemen memori dinamis.
  - Memisahkan buffer output untuk fungsi dan main loop (`_start`).
- **Build System**: `Makefile` mengotomatisasi kompilasi lokal dan cross-building ke VPS via SSH.

## Langkah Selanjutnya (Fase 2)
- Tipe data String yang lebih robust (length-prefixed).
- Array/Buffer manipulation functions.
- Standard Library yang lebih kaya.
