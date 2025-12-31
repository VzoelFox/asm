# Desain Struct Morph (Fase 1)

## 1. Syntax Definisi
Menggunakan keyword `struktur` dan `akhir`.
```ruby
struktur Point
    x int
    y int
akhir
```

## 2. Memory Layout
Karena Morph saat ini berbasis 64-bit integer (`int` dan `pointer` sama-sama 8 byte), kita menyederhanakan layout:
- Setiap field memakan **8 byte**.
- Tidak ada padding/packing alignment yang rumit (semua aligned 8 byte).
- Ukuran Struct = `Jumlah Field * 8`.

Contoh `Point`:
- Offset `x`: 0
- Offset `y`: 8
- Total Size: 16 bytes.

## 3. Instansiasi
Menggunakan syntax constructor-like (positional arguments) untuk kemudahan parsing di Bash, atau key-value jika memungkinkan.
Untuk Fase 1 (simplifikasi parser regex):
**Pilihan: Positional Constructor**
```ruby
var p = Point(10, 20)
```
Ini akan diterjemahkan menjadi:
1. `sys_alloc(16)` -> RAX (address struct).
2. Simpan 10 ke `[RAX + 0]`.
3. Simpan 20 ke `[RAX + 8]`.
4. Return RAX.

## 4. Akses Member
Menggunakan dot notation.
```ruby
var a = p.x
p.y = 100
```

## 5. Implementasi Compiler (Bash)
Kita perlu menyimpan "Symbol Table" struct di memori Bash saat parsing.
- `STRUCT_FIELDS_<StructName>`: Array berisi nama field urut.
- `STRUCT_OFFSET_<StructName>_<FieldName>`: Integer offset.
- `STRUCT_SIZE_<StructName>`: Total size.

Saat parser bertemu `Point(10, 20)`, dia akan:
1. Cek apakah `Point` adalah struct terdaftar.
2. Generate kode alokasi.
3. Generate kode pengisian field berurutan.

Saat parser bertemu `var.field`:
1. (Tantangan) Parser kita saat ini tidak tahu tipe data variabel `var`.
2. **Solusi Sementara**: Kita harus menyertakan nama struct saat akses? `Point.x(p)`?
3. **Solusi Lebih Baik**: Asumsi parser: jika ada `.` berarti akses struct. Tapi kita butuh tahu offset `x`.
   - Tanpa tipe data statis yang dicatat parser untuk variabel `p`, kita tidak tahu `p` itu `Point` atau `Rect`.
   - **Hack Fase 1**: Semua nama field harus unik secara global? Atau syntax eksplisit: `p->Point.x`?
   - Atau kita simpan tipe data variabel saat deklarasi `var p = Point(...)`?

**Keputusan Desain**:
Simpan tipe variabel di map `VAR_TYPE_<VarName>`.
Saat `var p = Point(...)`, set `VAR_TYPE_p = "Point"`.
Saat `p.x`, cek `VAR_TYPE_p`, dapatkan "Point", lalu cari offset `x` di `Point`.
Ini memungkinkan type checking statis minimal!
