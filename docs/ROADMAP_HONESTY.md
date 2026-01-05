# Roadmap Kejujuran & Perbaikan Morph
**Tanggal:** 2026-01-05
**Engineer:** Jules

Dokumen ini melacak perbaikan teknis yang diperlukan berdasarkan temuan di `docs/VERIFICATION_REPORT.md` untuk memastikan kejujuran implementasi dan mengembalikan fitur Granular Import ("Opsi A").

## 1. Pemulihan Granular Import (Prioritas Utama)
Mengembalikan kemampuan import berbasis ID (`Ambil`) yang merupakan fitur unik Morph.

- [x] **Desain Registry ID:** Tentukan range ID untuk library standar dan compiler.
- [x] **Buat File Registry:** Buat `indeks.fox` dengan sintaks `Daftar "file" = range`.
- [x] **Implementasi Markers:** Sisipkan `### <ID>` kembali ke `lib/builtins.fox` dan `lib/vector.fox`.
- [ ] **Implementasi Markers (Lanjutan):** Sisipkan ke `apps/compiler/src/*.fox`.
- [x] **Verifikasi:** Test case `examples/granular_test.fox` berhasil compile & run.

## 2. Perbaikan Bootstrap Compiler
Memperbaiki limitasi dan bug pada pondasi compiler (Bash script).

- [x] **Fix Recursion Depth:** Naikkan `MAX_PARSE_DEPTH` dari 3 ke 10.
- [x] **Dynamic Heap Reality:** Perbaiki klaim atau implementasi alokasi RAM.
    *   *Update:* Heap diubah menjadi hardcoded **800MB** (bukan dynamic 20%), Swap 200MB, Sandbox 100MB. Dokumentasi codegen sudah jujur.
- [x] **Split init_constants:** Pecah fungsi inisialisasi konstanta raksasa untuk mencegah stack overflow.

## 3. Daemon & Memori V2.2
Fitur manajemen memori otomatis berbasis waktu.

- [x] **Ukuran Memori:** Update `codegen.sh` ke 800MB Heap, 200MB Snapshot, 100MB Sandbox.
- [x] **Library Daemon:** Implementasi `lib/daemon.fox` dengan logika snapshot aging & cleanup.
- [ ] **Swap Granular:** *Pending* - Saat ini hanya mendukung penghapusan snapshot utuh, bukan variabel individu.

## 4. Bukti Verifikasi
Setiap item yang selesai ("Done") wajib menyertakan bukti di bawah ini.

| Item | Status | Bukti / Catatan |
|------|--------|-----------------|
| Roadmap Created | ✅ Done | Dokumen ini dibuat. |
| Granular Import | ✅ Done | `examples/granular_test.fox` generates valid ASM. |
| Heap Update | ✅ Done | `codegen.sh` updated to 800MB. |
| Daemon Logic | ✅ Done | `lib/daemon.fox` implemented. |
