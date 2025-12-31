# Desain Array Morph (Fase 2)

## 1. Syntax Deklarasi
Syntax mengikuti style C/Go:
```ruby
var arr [10]int
```
Atau sebagai field struct:
```ruby
struktur Data
    buffer [1024]int
akhir
```

## 2. Memory Layout
Array adalah blok memori sekuensial.
- Ukuran total = `Size * ElementSize`.
- ElementSize saat ini fixed 8 byte (int/ptr).
- Tidak ada header metadata di memori array itu sendiri (raw buffer). Metadata (size) hanya diketahui saat compile time atau disimpan terpisah jika perlu.

## 3. Akses Elemen
Syntax: `arr[index]`
- `index` bisa berupa integer literal atau variabel.
- Address efektif = `BaseAddress + (Index * 8)`.

## 4. Implementasi Compiler
### Symbol Table
- `VAR_IS_ARRAY_<VarName>`: 1 jika array.
- `VAR_ARRAY_SIZE_<VarName>`: Ukuran array.

### Parser & Codegen
- Saat deklarasi `var arr [10]int`:
  - `sys_alloc(10 * 8)` -> simpan pointer ke `var_arr`.
  - Tandai `arr` sebagai array (opsional, tapi `var_arr` sebenarnya hanyalah pointer ke buffer).
- Saat akses `arr[i]`:
  - Load pointer `arr` ke register (Base).
  - Load `i` ke register (Index).
  - `Address = Base + (Index * 8)`.
  - Load/Store nilai di Address.

### Nested Access
`p.buffer[i]`
1. Load struct pointer `p`.
2. Add offset field `buffer`.
3. Hasilnya adalah pointer ke array? Tidak.
   - Jika field struct dideklarasikan `buffer [10]int`, apakah struct menyimpan pointer ke array atau array inline?
   - **Desain Simpel**: Struct menyimpan **Pointer** ke array yang dialokasikan terpisah (mirip Java/C# reference types). Ini konsisten dengan semua field struct yang 8 byte.
   - Jadi `p.buffer` adalah pointer.
   - Logic `p.buffer[i]` sama dengan `arr[i]`. Load `p.buffer` (Base), lalu index.

**Kesimpulan**: Array adalah Pointer ke heap buffer.
`var arr [10]int` => `var arr = sys_alloc(80)`.
