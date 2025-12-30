# Morph Language Project

Ini adalah repositori pengembangan bahasa pemrograman **Morph**.

Saat ini proyek berada dalam fase **Bootstrap**, di mana compiler pertama ditulis menggunakan Shell Script untuk menghasilkan Assembly x86_64 yang berjalan secara *freestanding* (tanpa libc).

## Dokumentasi

Silakan baca [docs/BOOTSTRAP.md](docs/BOOTSTRAP.md) untuk detail teknis mengenai cara kerja compiler dan sistem build otomatis.

## Quick Start

Untuk menjalankan contoh "Hello World":

```bash
make all
```

Output yang diharapkan dari VPS:
```
--- Running on VPS ---
Halo dari Morph!
```
