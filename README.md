# AHK Shortcut Dev

AutoHotkey v2. Jalankan dengan double-click `main.ahk`.
CapsLock = tombol "leader" (fungsi caps dimatiin, pakai Shift buat kapital).

## Pakai

- **`CapsLock + klik kanan`**: jendela daftar dengan tab filter (History, Command, Folder, Macro, Script, Snippet). Double-click, atau pilih baris pakai panah lalu Enter = langsung jalan, Esc = tutup. Ctrl+Tab = ganti tab.
- **`CapsLock + huruf`**: shortcut langsung, huruf yang kamu set di config (kelihatan sebagai hint di menu).
- **`CapsLock + R`**: reload script.
- **Snippet**: ketik trigger (misal `;ok`) + spasi/Enter/Tab, atau klik dari menu.

## Struktur file

| File | Isi |
|---|---|
| `config.ahk` | Array bawaan (folders, commands, macros, snippets), sekarang kosong (cuma contoh format); entry baru ditambah lewat panel **+ Add** (disimpan di `custom.ini`) |
| `menu.ahk` | Mesin: bikin menu + daftarin hotkey/hotstring dari config |
| `main.ahk` | Entry point, include, `CapsLock+R` reload |
| `_old/` | Backup file versi lama (aman dihapus) |

Urutan include di `main.ahk` jangan diubah: config dulu, baru menu.

## Cara nambah / ubah (semua di `config.ahk`)

Setelah edit: **`CapsLock + R`**. Entry terakhir di list nggak pakai koma.

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
```

**Snippet**: `["trigger", "teks"]`, trigger diawali `;` biar nggak kepencet pas ngetik.
```
[";gm", "gas mainkan"],
```

## Catatan

- Key `R` dipakai reload. Kalau key di config bentrok, muncul pesan dan entry itu cuma ada di menu.
- Jendela muncul **setelah klik kanan dilepas** (`KeyWait`), supaya lepasnya klik nggak kepencet ke baris.
- Terminal pakai PowerShell `-NoExit` + `-ExecutionPolicy Bypass` supaya output/error tetap kelihatan dan script `.ps1`/`npm` bisa jalan. Command dikirim lewat `-EncodedCommand` (base64), jadi tanda kutip ganda dan karakter aneh di command aman. Baris pertama jendela (abu-abu, `> command`) menunjukkan apa yang dijalankan.
- Daftar punya item "Edit config.ahk" dan "Reload script" (tipe Script).

## Perilaku jendela (`menu.ahk`, fungsi `ShowMenu`)

- Tab: `History | Command | Folder | Macro | Script | Snippet`. History di paling depan (tab spesial, bukan tipe), sisanya urut alfabet dan nama tab = tipe entry, jadi kalau nambah tipe baru, tambah juga namanya di list tab.
- **History**: 100 entry terakhir yang dijalanin dari jendela ini (Enter / double-click), terbaru di atas, nggak dobel. Disimpan di `history.ini` (folder script), awet setelah reload dan restart. Shortcut `CapsLock + huruf` dan snippet hotstring nggak dicatat karena nggak lewat jendela. Entry yang sudah dihapus dari `config.ahk` otomatis nggak muncul. Hapus `history.ini` buat reset, atau klik kanan di tab History lalu pilih "Clear all history" (ada konfirmasi) / "Remove from History" buat satu entry. Limit ubah di `histMax` (`menu.ahk`). Kolom Type cuma tampil di tab ini.
- **Urutan**: tab Command/Folder/Macro/Script/Snippet diurutkan A-Z berdasarkan nama (nggak peduli huruf besar/kecil), otomatis, jadi urutan di `config.ahk` bebas. History tetap urut terbaru di atas.
- Tab terakhir dan ukuran jendela terakhir diingat selama script jalan (disimpan di `state`). Habis reload atau restart PC, balik ke default: tab `Command`, ukuran minimum `460x300`.
- Nggak ada baris yang kepilih otomatis pas dibuka: pilih pakai panah atau klik, lalu Enter / double-click.
- Teks yang tampil di jendela (judul, kolom, tab, pesan) pakai bahasa Inggris. Nama entry di `config.ahk` bebas, komentar boleh Indonesia.
- Ukuran awal: kebuka di ukuran terakhir (default ukuran minimum `w460 h300`, sama dengan `+MinSize`), bisa ditarik lebih besar. Tab + list ikut lebar, list ikut tinggi, kolom Name nyerap sisa lebar (Shortcut `140` tetap; kolom Type `80` cuma tampil di tab History, di tab lain disembunyiin karena isinya sama dengan nama tab, jadi Name lebih lebar). Lebar dihitung pas buka, resize, dan ganti tab. Minimize dan maximize dimatiin (`-MinimizeBox -MaximizeBox`), resize lewat tarik pinggir tetap bisa. Tampilan glass ikut tema sistem (WinHawk).

## Tambah entry dari panel (+ Add)

Tombol **+ Add** di pojok kanan bawah jendela. **Klik kanan di area kosong panel** (margin kiri/kanan, strip bawah) membuka menu script: Reload script, Open script folder, Edit config.ahk, dan Clear all history yang cuma muncul di tab History. Tipe yang sudah ada: **Command**, **Folder**, **Macro**, dan **Snippet** (tipe App sudah dihapus, buat aplikasi pakai Command; entry App lama di `custom.ini` otomatis kebaca sebagai Command). Form dibangun ulang tiap ganti tipe, isian yang sudah diketik (nama, folder, command, key) ikut terbawa.
- **Command**: nama, folder tempat jalan (ada tombol Browse, picker folder modern), command satu baris, key opsional. Muncul di tab Command, jalan lewat `RunCommand` (`-EncodedCommand`). File `.bat` / `.exe` bisa langsung ditulis path-nya, kalau ada spasi pakai `& "path lengkap"`. Dicek: semua wajib diisi kecuali key, command harus satu baris, folder harus ada, **nama nggak boleh kembar di tab yang sama**, key seperti Folder.
- **Folder**: nama, path (ada tombol Browse), key opsional. Dicek: folder harus ada, key 1 huruf/angka, nggak boleh bentrok (`usedKeys`).
- **Macro**: nama, keys (sintaks `Send` AHK), tombol **Test**, tombol **Record**, app (opsional), key (opsional). Tombol **Record**: klik, lalu tekan kombinasinya (misal Ctrl+Alt+Shift+C), otomatis ditulis ke kolom keys sebagai `^!+c`; Esc sendirian = batal. Tombol **Test** menyembunyikan form, kasih jeda 3 detik buat pindah ke app tujuan, lalu mengirim keys-nya ke sana (keys yang salah sintaks ketahuan di sini). Dropdown **App** berisi app yang lagi kebuka + `RobloxStudioBeta.exe`, atau ketik nama exe sendiri. Kalau app diisi, `CapsLock + key` cuma jalan di app itu, jadi huruf yang sama bisa dipakai lagi buat app lain. Nama di list tampil `Nama  [app.exe]`. Dicek: nama dan keys wajib, nama nggak boleh kembar (per app), key seperti Folder tapi dihitung per app.
- **Snippet**: trigger (otomatis diawali `;`, nggak boleh spasi, nggak boleh dobel) dan teks yang diketik.
- Disimpan di `custom.ini` (satu section per entry: `type`, `label`, `value`, `key`, plus `dir` untuk Command dan `win` untuk Macro), langsung aktif tanpa reload. File ini di `.gitignore`, formatnya UTF-16 supaya emoji/aksen aman.
- Edit: klik kanan entry lalu **Edit entry**. Form yang sama kebuka dengan isian lama dan tipenya terkunci (tipe nggak bisa diganti), tombolnya **Save**. Semua field boleh diubah. Cek bentrok (nama, key, trigger) mengabaikan entry itu sendiri, jadi nama atau key lama boleh dipakai lagi. Kalau nama tetap, posisinya di History dipertahankan; kalau nama berubah, baris lama di History dibuang. Kalau simpan gagal, entry lama dikembalikan. Entry dari `config.ahk` nggak punya menu ini, tetap diedit manual.
- Hapus: klik kanan entry lalu **Remove entry** (key/trigger dimatikan, hilang dari `custom.ini` dan History). Hanya entry dari panel yang bisa dihapus dari sini, entry dari `config.ahk` tetap diedit manual.
- Di teks AHK, tanda `;` setelah spasi dianggap komentar walau di dalam tanda kutip, tulis `` `; `` kalau mau `;` biasa di dalam string.

## Roadmap

**Macro / remap shortcut (engine sudah jadi, isi macro belum)**

Masalah: shortcut bawaan aplikasi sering bentrok, dan di keyboard 60% shortcut jadi harus kombinasi 3-4 tombol, ribet dipencet. F1-F12, panah, Home/End/PgUp/PgDn nggak perlu diremap karena sudah ada lewat Fn bawaan keyboard.

Sudah jadi: jenis entry **Macro** (tab sendiri di menu, array `macros` di `config.ahk`) dengan `CapsLock + huruf` sebagai satu-satunya "tombol pintu".
- Format: `["Label", "keys", "key", "window"]`, `keys` pakai sintaks `Send` AHK (`^+s`, `{Enter}`, `{Left 3}`), `key` dan `window` opsional.
- `window` (misal `"ahk_exe Code.exe"`) bikin huruf itu cuma jalan di app tersebut, jadi satu huruf bisa beda fungsi per program.
- Dicek bentrok lewat `usedKeys` (per huruf, per window).

Belum: macro dengan jeda antar langkah. Macro baru ditambah lewat panel **+ Add** (tab Macro), nggak perlu edit `config.ahk`.

Catatan: key yang sudah terpakai `R` (reload) dan `V` (clipboard history). Macro nggak bisa direkam otomatis di AHK v2, jadi ditulis manual di config.

**Panel + Add (urutan kerja, satu langkah satu commit)**

Tujuan: semua entry ditambah lewat panel, `config.ahk` tinggal contoh format. Satu langkah satu commit, urut dari atas.

- [x] Tahap 1: Folder + Snippet, simpan ke `custom.ini`, Remove entry, cek bentrok key/trigger.
- [x] **Hapus entry Roblox Studio otomatis** (`placesFile`, `FindStudio`, `OpenStudio`, `LoadPlaces` + pemanggilnya di `BuildItems`, dan catatannya di README). Buka place tetap lewat app Open Place. Entry lama di History hilang sendiri.
- [x] Menu script lewat **klik kanan di area kosong panel** (awalnya tombol ⚙, dibuang karena jelek). Isinya: Reload script, Open script folder, Edit config.ahk, dan Clear all history (cuma di tab History).
- [x] **Command pakai `-EncodedCommand`**: `RunCommand` meng-encode command (base64 UTF-16) sebelum dikirim ke PowerShell, jadi tanda kutip ganda dan karakter aneh aman tanpa validasi. Tetap `-NoExit`, folder jalan tetap, opsional `Write-Host` command di awal biar kelihatan. Berlaku juga untuk entry `config.ahk`.
- [x] Tahap 2: tipe **App** dan **Command** di form Add. Urutan field: **Name, Folder + Browse (folder tempat jalan), Command (satu baris), Key (opsional)**. Urutan field tipe lain tetap: Folder = Name, Folder, Key; Snippet = Trigger, Text. Format App dan Command sama, bedanya cuma tab tujuan, disimpan di `custom.ini` dengan field tambahan `dir`. Form dibangun ulang tiap ganti tipe (bukan sekadar `.Visible`, supaya nggak bolong). Tambah cek **nama kembar per tipe** saat Save (History pakai ID `Tipe|Nama`).
- [x] Bersihin `config.ahk`: array apps, folders, commands, snippets dikosongkan (entry lama dihapus, ditambah ulang lewat panel), termasuk folder `AHK Shortcut (edit)` + key `S` yang diganti menu klik kanan (Open script folder). Macro Auto click juga sudah dihapus (lihat langkah **Hapus auto click** di bawah). Item Script bawaan nggak ikut.
- [x] Tahap 3: tipe **Macro** di form Add (name, keys, tombol Test, app opsional, key), disimpan di `custom.ini` dengan field `win`. Dipakai buat remap shortcut susah jadi `CapsLock + huruf`, misalnya kombinasi custom di Roblox Studio.
- [x] **Edit entry** (klik kanan entry di panel, lalu Edit entry): form Add dipakai ulang dengan field terisi dan tipe terkunci. Nama berubah = baris lama di History dibuang (bukan diganti), nama tetap = posisi di History dipertahankan. Simpan gagal = entry lama dikembalikan.
- [x] **Hapus auto click**: fitur `click:ms` (ToggleClick, validasi `click:` di form Add, dan macro Auto click di `config.ahk`) dibuang karena nggak bisa dites dari form Add. Macro biasa (sintaks `Send`), Test, Record, dan dropdown App tetap jalan. `RobloxStudioBeta.exe` di dropdown App tetap, itu buat macro per-app, bukan auto click.
- Ditunda: app Xyra Studio yang cara jalannya beda dari `tauri dev` biasa, belum jelas butuh tipe tambahan atau nggak.
