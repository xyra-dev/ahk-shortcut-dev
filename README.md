# AHK Shortcut Dev

AutoHotkey v2. Jalankan dengan double-click `main.ahk`.
CapsLock = tombol "leader" (fungsi caps dimatiin, pakai Shift buat kapital).

## Pakai

- **`CapsLock + klik kanan`**: jendela daftar dengan tab filter (History, Apps, Command, Folder, Script, Snippet). Double-click, atau pilih baris pakai panah lalu Enter = langsung jalan, Esc = tutup. Ctrl+Tab = ganti tab.
- **`CapsLock + huruf`**: shortcut langsung, huruf yang kamu set di config (kelihatan sebagai hint di menu).
- **`CapsLock + R`**: reload script.
- **Snippet**: ketik trigger (misal `;ok`) + spasi/Enter/Tab, atau klik dari menu.

## Struktur file

| File | Isi |
|---|---|
| `config.ahk` | **Satu-satunya file yang diedit**: apps, folders, commands, snippets |
| `menu.ahk` | Mesin: bikin menu + daftarin hotkey/hotstring dari config |
| `main.ahk` | Entry point, include, `CapsLock+R` reload |
| `_old/` | Backup file versi lama (aman dihapus) |

Urutan include di `main.ahk` jangan diubah: config dulu, baru menu.

## Cara nambah / ubah (semua di `config.ahk`)

Setelah edit: **`CapsLock + R`**. Entry terakhir di list nggak pakai koma.

**App**: format sama persis dengan Command, `["Label", "folder tempat jalan", "command", "key"]`, key opsional. Bedanya cuma tampil di tab **Apps**, buat shortcut ke aplikasimu.
```
["Xyra Dashboard", "C:\Dev_Ex\Apps\Xyra_Dashboard_Wip2", "npm run tauri dev", "d"],
```

**Folder**: `["Label", "path", "key"]`, key opsional.
```
["Blender", "C:\Dev_Ex\Blender", "b"],
```
Dengan key `b`, `CapsLock + B` langsung buka folder, dan menu nampilin hint-nya.

**Command**: `["Label", "folder tempat jalan", "command", "key"]`, key opsional.
```
["Git pull", "C:\Dev_Ex\Apps\Dev_Zee_Tools", "git pull"],
```

**Macro**: `["Label", "keys", "key", "window"]`, `key` dan `window` opsional. `keys` pakai sintaks `Send` AHK (`^` Ctrl, `+` Shift, `!` Alt, `#` Win, `{Enter}`, `{Left 3}`). Kalau `window` diisi, huruf itu cuma jalan di app tersebut.
```
["Save all", "^+s", "u"],
["Delete line", "{Home}+{End}{Delete}", "k", "ahk_exe Code.exe"],
["Auto click (100 ms)", "click:100", "j"],
```
`click:ms` = **auto click** toggle: klik kiri tiap `ms` milidetik di posisi mouse, tekan lagi (atau jalankan dari menu lagi) buat berhenti. Cuma satu auto click jalan sekaligus, dan otomatis berhenti / ditolak kalau window **Roblox Player** (`RobloxPlayerBeta.exe`) lagi aktif, karena auto click di game bisa dianggap curang. Roblox Studio aman.

**Snippet**: `["trigger", "teks"]`, trigger diawali `;` biar nggak kepencet pas ngetik.
```
[";gm", "gas mainkan"],
```

## Catatan

- Key `R` dipakai reload. Kalau key di config bentrok, muncul pesan dan entry itu cuma ada di menu.
- Jendela muncul **setelah klik kanan dilepas** (`KeyWait`), supaya lepasnya klik nggak kepencet ke baris.
- Terminal pakai PowerShell `-NoExit` + `-ExecutionPolicy Bypass` supaya output/error tetap kelihatan dan script `.ps1`/`npm` bisa jalan.
- Daftar punya item "Edit config.ahk" dan "Reload script" (tipe Script).
- **Roblox Studio di tab Apps**: satu baris per place dari `places.json` milik app Open Place (`%APPDATA%\com.gztudio.openplace\places.json`, cuma dibaca, nggak diubah), namanya `Roblox Studio : nama place`. Double-click / Enter = buka place di Roblox Studio (`RobloxStudioBeta.exe --task EditPlace --placeId --universeId`, versi Studio terbaru dicari otomatis). Place tanpa Universe ID muncul pesan, nggak jalan. Tambah/hapus place lewat app Open Place, lalu `CapsLock + R` supaya daftar ke-refresh. Kalau file nggak ada, barisnya nggak muncul. Hanya Edit (Studio), Play tetap lewat Open Place.

## Perilaku jendela (`menu.ahk`, fungsi `ShowMenu`)

- Tab: `History | Apps | Command | Folder | Macro | Script | Snippet`. History di paling depan (tab spesial, bukan tipe), sisanya urut alfabet dan nama tab = tipe entry, jadi kalau nambah tipe baru, tambah juga namanya di list tab.
- **History**: 100 entry terakhir yang dijalanin dari jendela ini (Enter / double-click), terbaru di atas, nggak dobel. Disimpan di `history.ini` (folder script), awet setelah reload dan restart. Shortcut `CapsLock + huruf` dan snippet hotstring nggak dicatat karena nggak lewat jendela. Entry yang sudah dihapus dari `config.ahk` otomatis nggak muncul. Hapus `history.ini` buat reset, atau klik kanan di tab History lalu pilih "Clear all history" (ada konfirmasi) / "Remove from History" buat satu entry. Limit ubah di `histMax` (`menu.ahk`). Kolom Type cuma tampil di tab ini.
- **Urutan**: tab Apps/Command/Folder/Macro/Script/Snippet diurutkan A-Z berdasarkan nama (nggak peduli huruf besar/kecil), otomatis, jadi urutan di `config.ahk` bebas. History tetap urut terbaru di atas.
- Tab terakhir dan ukuran jendela terakhir diingat selama script jalan (disimpan di `state`). Habis reload atau restart PC, balik ke default: tab `Apps`, ukuran minimum `460x300`.
- Nggak ada baris yang kepilih otomatis pas dibuka: pilih pakai panah atau klik, lalu Enter / double-click.
- Teks yang tampil di jendela (judul, kolom, tab, pesan) pakai bahasa Inggris. Nama entry di `config.ahk` bebas, komentar boleh Indonesia.
- Ukuran awal: kebuka di ukuran terakhir (default ukuran minimum `w460 h300`, sama dengan `+MinSize`), bisa ditarik lebih besar. Tab + list ikut lebar, list ikut tinggi, kolom Name nyerap sisa lebar (Shortcut `140` tetap; kolom Type `80` cuma tampil di tab History, di tab lain disembunyiin karena isinya sama dengan nama tab, jadi Name lebih lebar). Lebar dihitung pas buka, resize, dan ganti tab. Minimize dan maximize dimatiin (`-MinimizeBox -MaximizeBox`), resize lewat tarik pinggir tetap bisa. Tampilan glass ikut tema sistem (WinHawk).

## Tambah entry dari panel (+ Add)

Tombol **+ Add** di pojok kanan bawah jendela. Tipe yang sudah ada: **Folder** dan **Snippet**.
- **Folder**: nama, path (ada tombol Browse), key opsional. Dicek: folder harus ada, key 1 huruf/angka, nggak boleh bentrok (`usedKeys`).
- **Snippet**: trigger (otomatis diawali `;`, nggak boleh spasi, nggak boleh dobel) dan teks yang diketik.
- Disimpan di `custom.ini` (satu section per entry: `type`, `label`, `value`, `key`), langsung aktif tanpa reload. File ini di `.gitignore`, formatnya UTF-16 supaya emoji/aksen aman.
- Hapus: klik kanan entry lalu **Remove entry** (key/trigger dimatikan, hilang dari `custom.ini` dan History). Hanya entry dari panel yang bisa dihapus dari sini, entry dari `config.ahk` tetap diedit manual.
- Di teks AHK, tanda `;` setelah spasi dianggap komentar walau di dalam tanda kutip, tulis `` `; `` kalau mau `;` biasa di dalam string.

## Roadmap

**Macro / remap shortcut (engine sudah jadi, isi macro belum)**

Masalah: shortcut bawaan aplikasi sering bentrok, dan di keyboard 60% shortcut jadi harus kombinasi 3-4 tombol, ribet dipencet. F1-F12, panah, Home/End/PgUp/PgDn nggak perlu diremap karena sudah ada lewat Fn bawaan keyboard.

Sudah jadi: jenis entry **Macro** (tab sendiri di menu, array `macros` di `config.ahk`) dengan `CapsLock + huruf` sebagai satu-satunya "tombol pintu".
- Format: `["Label", "keys", "key", "window"]`, `keys` pakai sintaks `Send` AHK (`^+s`, `{Enter}`, `{Left 3}`), `key` dan `window` opsional.
- `window` (misal `"ahk_exe Code.exe"`) bikin huruf itu cuma jalan di app tersebut, jadi satu huruf bisa beda fungsi per program.
- Dicek bentrok lewat `usedKeys` (per huruf, per window).

Belum: isi macro sebenarnya (nunggu daftar kombinasi yang paling nyebelin dipencet), macro dengan jeda antar langkah.

Catatan: key yang sudah terpakai `R` (reload) dan `V` (clipboard history). Macro nggak bisa direkam otomatis di AHK v2, jadi ditulis manual di config.

**Panel + Add (urutan kerja, satu langkah satu commit)**

- [x] Tahap 1: Folder + Snippet, simpan ke `custom.ini`, Remove entry, cek bentrok key/trigger.
- [ ] Tombol **⚙** kecil di strip bawah, di samping **+ Add**. Menunya: Reload script, Open script folder, Edit config.ahk, dan Clear all history (cuma di tab History). Klik kanan area kosong sengaja nggak dipakai.
- [ ] Tahap 2: tipe **App** dan **Command** di form Add (nama, folder tempat jalan + Browse, command, key opsional). Format keduanya sama, bedanya cuma tab tujuan. Hati-hati tanda kutip ganda di command (dibungkus `-Command "..."`).
- [ ] Bersihin `config.ahk`: entry lama di-comment (jangan dihapus total, jadi contoh format), termasuk folder `AHK Shortcut (edit)` + key `S` yang diganti tombol ⚙. Yang nggak ikut: item Script bawaan dan baris Roblox Studio dari Open Place.
- [ ] Tahap 3: tipe **Macro** (sintaks `Send` rawan salah, mungkin perlu tombol Test). Ditunda sampai ada daftar kombinasi yang mau dibikin.
- Edit entry sengaja ditunda: History pakai ID `Tipe|Nama`, jadi ganti nama memutus History. Remove lalu Add ulang cukup untuk sekarang.
