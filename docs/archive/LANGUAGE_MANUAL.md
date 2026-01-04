# Manual Bahasa Pemrograman Morph v1.0

Referensi lengkap sintaks dan perpustakaan standar Morph.

## 1. Sintaks Dasar

### Variabel & Tipe Data
Morph menggunakan *Type Inference* sederhana untuk integer dan pointer.
```morph
var x = 10
var y = "Hello"      ; String literal (pointer)
var z = x + 5
```

### Struktur (Struct)
Mendefinisikan tipe data komposit.
```morph
struktur Point
  x int
  y int
tutup_struktur

; Instansiasi
var p = Point(10, 20)

; Akses Field (Membutuhkan Type Hinting 'tipe')
tipe p Point
var px = p.x
p.y = 30
```

### Fungsi
```morph
fungsi tambah(a, b)
  var hasil = a + b

  ; Return value via RAX (assembly convention)
  asm_mulai
  mov rax, [var_hasil]
  tutup_asm
tutup_fungsi

; Pemanggilan (Eksplisit)
panggil tambah(10, 20)

; Pemanggilan (Implisit - Baru di v1.1)
tambah(10, 20)

; Assignment dari Fungsi
var hasil = tambah(5, 5)
```

### Kontrol Alur (Control Flow)

**Percabangan (If-Else):**
```morph
jika (x > 10)
  cetak("Besar")
lain_jika (x == 10)
  cetak("Pas")
lain
  cetak("Kecil")
tutup_jika
```

**Perulangan (Loop):**
```morph
selama (i < 5)
  cetak(i)
  i = i + 1
tutup_selama
```

### Import Granular (Sistem Tagger)
Morph menggunakan sistem import unik berbasis ID untuk efisiensi "Zero-Abstraction".

1.  **Load Index:** `indeks "path/to/tagger.fox"`
2.  **Import:** `Ambil ID1, ID2, ...`

```morph
indeks "plugins/vc/tagger.fox"
Ambil 310, 311 ; Mengambil Buffer Library
```

## 2. Standard Library

### Buffer (`lib/buffer.fox`) - ID 310-319
Manipulasi memori mentah dan I/O stream.
- `buffer_buat(cap)`: Membuat buffer baru.
- `buffer_tulis(buf, data)`: Menulis string/data ke buffer.
- `buffer_baca(buf, size)`: Membaca n-byte.

### Vector (`lib/vector.fox`) - ID 340-349
Array dinamis (List).
- `vec_create(cap)`: Membuat vector.
- `vec_push(vec, item)`: Menambah item ke akhir.
- `vec_get(vec, idx)`: Mengambil item di index.
- `vec_len(vec)`: Mendapatkan panjang.

### Hashmap (`lib/hashmap.fox`) - ID 330-339
Key-Value store (String Key -> Int Value).
- `map_create(cap)`: Membuat map.
- `map_put(map, key, val)`: Menyimpan nilai.
- `map_get(map, key)`: Mengambil nilai.

### File I/O (`lib/file_io.fox`) - ID 318
Operasi file sistem (Baru di v1.0).
- `buffer_dari_file(filepath)`: Membaca seluruh file ke dalam `MemoryBuffer`.

### String Utils (`lib/string_utils.fox`) - ID 380-389
Manipulasi teks (Baru di v1.0).
- `str_split_lines(content, vec)`: Memecah string menjadi baris-baris (disimpan di Vector).
- `str_trim(s)`: Menghapus whitespace di awal/akhir.
- `str_starts_with(s, prefix)`: Cek prefix string.

### JSON (`lib/json.fox`) - ID 350-369
Parser JSON lengkap.
- `json_parse(str)`: Mengubah string JSON menjadi struct `JsonValue`.
- `json_stringify(val)`: Mengubah `JsonValue` menjadi string.

## 3. CLI Runner

Gunakan `./morph` untuk menjalankan kode.
```bash
./morph aplikasi_saya.fox
```
Script ini menangani kompilasi lokal, deploy ke VPS, dan eksekusi remote secara transparan.
