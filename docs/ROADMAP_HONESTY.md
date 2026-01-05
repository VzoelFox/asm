# Roadmap Kejujuran & Perbaikan Morph
**Tanggal:** 2026-01-05
**Engineer:** Jules

Dokumen ini melacak perbaikan teknis yang diperlukan berdasarkan temuan di `docs/VERIFICATION_REPORT.md` untuk memastikan kejujuran implementasi dan mengembalikan fitur Granular Import ("Opsi A").

## 1. Pemulihan Granular Import (Prioritas Utama)
Mengembalikan kemampuan import berbasis ID (`Ambil`) yang merupakan fitur unik Morph.

- [ ] **Desain Registry ID:** Tentukan range ID untuk library standar dan compiler.
- [ ] **Buat File Registry:** Buat `indeks.fox` dengan sintaks `Daftar "file" = range`.
- [ ] **Implementasi Markers:** Sisipkan `### <ID>` kembali ke file `lib/*.fox`.
- [ ] **Implementasi Markers (Compiler):** Sisipkan `### <ID>` kembali ke `apps/compiler/src/*.fox`.
- [ ] **Verifikasi:** Test case `examples/granular_test.fox` berhasil compile & run.

## 2. Perbaikan Bootstrap Compiler
Memperbaiki limitasi dan bug pada pondasi compiler (Bash script).

- [ ] **Fix Recursion Depth:** Naikkan `MAX_PARSE_DEPTH` dari 3 ke 10.
- [ ] **Dynamic Heap Reality:** Perbaiki klaim atau implementasi alokasi RAM (saat ini hardcoded 64MB).
- [ ] **Split init_constants:** Pecah fungsi inisialisasi konstanta raksasa untuk mencegah stack overflow (klaim palsu sebelumnya).

## 3. Self-Hosted Compiler Integrity
Memastikan compiler yang ditulis dalam Morph (self-hosted) jujur dan sinkron dengan bootstrap.

- [ ] **Parser Helpers:** Pastikan logika `Ambil` di `parser_helpers_import.fox` sinkron dengan bootstrap.
- [ ] **Documentation:** Update komentar versi dan kapabilitas agar sesuai fakta.

## 4. Bukti Verifikasi
Setiap item yang selesai ("Done") wajib menyertakan bukti di bawah ini.

| Item | Status | Bukti / Catatan |
|------|--------|-----------------|
| Roadmap Created | ✅ Done | Dokumen ini dibuat. |
