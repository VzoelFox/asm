# Kernel Map & ID Registry

Dokumen ini memetakan Fungsi Kernel dan Pustaka Standar Morph ke ID Blok unik global (`### ID`).
Sistem ini memungkinkan import tanpa path (`Ambil <ID>`) dengan bantuan file indeks (`tagger.fox`).

## Alokasi ID

| Range ID | Kategori | Path Referensi |
| :--- | :--- | :--- |
| **0 - 99** | **Reserved / Kernel Core** | (Internal Compiler) |
| **100 - 199** | **Matematika Dasar** | `lib/math.fox` |
| **200 - 299** | **String & Text** | `lib/string.fox` |
| **300 - 399** | **Input / Output (IO)** | `lib/io.fox` |
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

---

## Format Tagger (`tagger.fox`)

File tagger bertugas mendaftarkan lokasi ID ke Compiler.

```morph
; Mendaftarkan Range ID ke File
Daftar "lib/math.fox" = 100-105
Daftar "lib/string.fox" = 200, 201
```

## Penggunaan (`main.fox`)

```morph
; Muat indeks dulu
indeks "plugins/vc/tagger.fox"

; Ambil fungsi langsung by ID (Compiler mencari path-nya sendiri)
Ambil 100, 101
```
