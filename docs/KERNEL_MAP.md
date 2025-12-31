# Kernel Map & ID Registry

Dokumen ini memetakan Fungsi Kernel dan Pustaka Standar Morph ke ID Blok unik global (`### ID`).
Sistem ini memungkinkan import tanpa path (`Ambil <ID>`) dengan bantuan file indeks (`tagger.fox`).

## Alokasi ID

| Range ID | Kategori | Path Referensi |
| :--- | :--- | :--- |
| **0 - 99** | **Reserved / Kernel Core** | (Internal Compiler) |
| **100 - 199** | **Matematika Dasar** | `lib/math.fox` |
| **200 - 299** | **String & Text** | `lib/string.fox` |
| **300 - 399** | **Input / Output (IO)** | `lib/io.fox`, `lib/buffer.fox`, `lib/format.fox` |
| **400 - 499** | **System & Process** | `lib/sys.fox` |
| **500+** | **User / Plugins** | (Bebas) |

## Daftar Fungsi (Implementasi Saat Ini)

### Matematika (100 - 199)
Lokasi: `lib/math.fox`

*   `### 100` -> `fungsi math_tambah(a, b)`: Mengembalikan a + b.
*   `### 101` -> `fungsi math_kurang(a, b)`: Mengembalikan a - b.

### String (200 - 299)
Lokasi: `lib/string.fox` (Rencana)

*   `### 200` -> `fungsi str_len(s)`: Panjang string.
*   `### 201` -> `fungsi str_eq(a, b)`: Bandingkan string.

### Buffer I/O (310 - 319)
Lokasi: `lib/buffer.fox`

*   `### 310` -> `fungsi buffer_buat(capacity)`: Membuat buffer baru.
*   `### 311` -> `fungsi buffer_tulis(buf, data)`: Menulis data ke buffer.
*   `### 312` -> `fungsi buffer_baca(buf, size)`: Membaca data dari buffer.
*   `### 313` -> `fungsi buffer_seek(buf, pos)`: Mengubah posisi pointer.
*   `### 314` -> `fungsi buffer_size(buf)`: Mendapatkan ukuran buffer.
*   `### 315` -> `fungsi buffer_reset(buf)`: Mengosongkan buffer.
*   `### 316` -> `fungsi buffer_readonly(buf)`: Mengunci buffer (read-only).

### Format Library (320 - 329)
Lokasi: `lib/format.fox`

*   `### 320` -> `fungsi format_buffer_buat(capacity)`: Membuat format buffer.
*   `### 321` -> `fungsi format_append(buf, text)`: Menambah text ke buffer.
*   `### 322` -> `fungsi format_int(value)`: Konversi int ke string.
*   `### 323` -> `fungsi format_bool(value)`: Konversi bool ke string.
*   `### 324` -> `fungsi format_print(text)`: Print string.

---

## Format Tagger (`tagger.fox`)

File tagger bertugas mendaftarkan lokasi ID ke Compiler.

```morph
; Mendaftarkan Range ID ke File
Daftar "lib/math.fox" = 100-105
Daftar "lib/string.fox" = 200, 201
Daftar "lib/buffer.fox" = 310-319
Daftar "lib/format.fox" = 320-329
```

## Penggunaan (`main.fox`)

```morph
; Muat indeks dulu
indeks "plugins/vc/tagger.fox"

; Ambil fungsi langsung by ID (Compiler mencari path-nya sendiri)
Ambil 100, 101
```
