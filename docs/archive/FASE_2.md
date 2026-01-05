# Morph Fase 2: Standard Library & Data Structures

Fase ini berfokus pada pembangunan infrastruktur logika (Standard Library) di atas fondasi assembly yang telah dibangun di Fase 1. Tujuannya adalah menyediakan struktur data dan utilitas tingkat tinggi untuk memungkinkan pengembangan aplikasi kompleks (seperti Database) tanpa harus berurusan dengan alokasi memori manual atau assembly setiap saat.

## Pencapaian Utama

### 1. Sistem Buffer I/O (`lib/buffer.fox`)
Implementasi buffer memori untuk operasi I/O yang efisien dan aman.
- Menggantikan syscall I/O langsung.
- Mendukung Create, Write, Read, Seek, Reset.
- Fitur Read-Only protection.

### 2. Format Library (`lib/format.fox`)
Utilitas manipulasi string dan konversi tipe dasar.
- Pengganti `printf`/`scanf` sederhana.
- `format_int`, `format_bool` untuk konversi.
- `FormatBuffer` untuk string building yang efisien.

### 3. Struktur Data: Hashmap (`lib/hashmap.fox`)
Implementasi *Key-Value Store* menggunakan algoritma DJB2 hashing dan Separate Chaining (Linked List).
- Operasi: Create, Put, Get, Update, Collision Handling.
- Fondasi untuk JSON Object dan Database Indexing.

### 4. Struktur Data: Vector (`lib/vector.fox`)
Implementasi *Dynamic Array* (List) yang otomatis membesar (auto-resize).
- Operasi: Create, Push, Get, Set, Len.
- Fondasi untuk JSON Array dan list data.

### 5. Compiler Enhancement: Explicit Type Hinting (`tipe`)
Peningkatan signifikan pada Parser untuk mengatasi masalah "Type Erasure".
- Keyword `tipe <var> <Struct>` memungkinkan parser mengenali tipe struktur.
- Memungkinkan akses field via dot notation (`obj.field`) secara native tanpa perlu menulis Assembly manual.
- Membersihkan kode library dari "Hutang Teknis".

### 6. JSON Parser (`lib/json.fox`)
Mahakarya Fase 2: Parser JSON rekursif penuh.
- Mendukung Object (`{}`), Array (`[]`), String, Number, Boolean, Null.
- Menggunakan Hashmap untuk Object dan Vector untuk Array.
- API `json_parse` dan `json_stringify`.

## Kesimpulan
Dengan selesainya Fase 2, Morph kini memiliki "Standard Template Library" (STL) minimalis namun robust. Kita siap melangkah ke **Fase 3: Database & Networking**.
