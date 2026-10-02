# Fix: Hyprlock Selalu Bilang "Wrong Password"

Catatan cara memperbaiki bug hyprlock yang menolak password padahal sudah benar.
Dipakai lagi kalau kejadian di device lain (laptop/PC baru, install ulang, dll).

## Gejala

- Password sudah benar tapi hyprlock tetap menampilkan `fail_text` (wrong password / authentication failed).
- Biasanya muncul setelah suspend/resume, atau setelah beberapa kali salah ketik.
- Kadang cuma bisa diatasi dengan reboot paksa.

## Penyebab (ada 2 kemungkinan, cek dua-duanya)

Root cause-nya ada di stack PAM yang dipakai `/etc/pam.d/hyprlock`, bukan di
`hyprlock.conf`. Dua penyebab paling umum:

### 1. `pam_fprintd.so` (fingerprint) nyangkut di auth stack

Kalau `/etc/pam.d/hyprlock` isinya `auth include login` (default di banyak distro),
itu ngikutin stack `system-auth`, yang sering punya baris:

```
auth        sufficient   pam_fprintd.so
auth        sufficient   pam_unix.so
```

Kalau fitur fingerprint aktif di sistem tapi device fingerprint-nya nggak ada/error
(umum di desktop PC atau laptop tanpa reader), modul `pam_fprintd` bisa bikin
hyprlock salah baca hasil auth dan nolak password yang sebenarnya benar.

**Cek apakah ini penyebabnya:**

```bash
# Fedora/RHEL (authselect)
authselect current
# lihat apakah ada "with-fingerprint" di "Enabled features"

# Cek device fingerprint ada atau nggak
fprintd-list "$USER"
# kalau outputnya "No devices available" tapi with-fingerprint aktif -> ini penyebabnya
```

### 2. `pam_faillock.so` mengunci akun setelah beberapa kali salah

Kalau sistemnya pakai `pam_faillock`, setelah beberapa kali salah password,
akun bisa terkunci sementara (`unlock_time`) — password yang benar pun ditolak
selama masa lock itu, kesannya seperti hyprlock rusak.

**Cek apakah ini penyebabnya:**

```bash
# Fedora/RHEL (authselect)
authselect current
# lihat apakah ada "with-faillock" di "Enabled features"

# Arch/distro lain, cek langsung isi stack-nya
grep -r pam_faillock /etc/pam.d/system-auth /etc/pam.d/hyprlock 2>/dev/null

# Cek status lock user saat ini
faillock --user "$USER"
```

## Fix

### Solusi umum: kasih hyprlock PAM stack sendiri (skip fprintd & faillock)

Ini yang paling aman dan cocok untuk kedua kasus di atas, karena stack-nya cuma
verifikasi password lewat `pam_unix.so`, tanpa fingerprint dan tanpa faillock.

```bash
# 1. Backup config lama
sudo cp /etc/pam.d/hyprlock /etc/pam.d/hyprlock.backup

# 2. Ganti dengan stack minimal
sudo tee /etc/pam.d/hyprlock >/dev/null <<'EOF'
# PAM configuration for hyprlock
# Bypasses pam_fprintd/pam_faillock — only unix password auth.
auth        required    pam_unix.so try_first_pass nullok
account     required    pam_unix.so
EOF

# 3. Kalau ada user yang kepalang ke-lock oleh faillock, reset dulu
sudo faillock --user "$USER" --reset

# 4. Reload hyprlock (nggak perlu restart Hyprland/reboot)
pkill hyprlock
```

Setelah ini, hyprlock hanya cek password lewat `pam_unix.so` — login sistem,
sudo, dan service lain tetap pakai `system-auth` normal (fingerprint tetap
jalan untuk login/sudo, cuma nggak dipakai di lock screen).

### Rollback (kalau ada masalah lain setelah fix)

```bash
sudo cp /etc/pam.d/hyprlock.backup /etc/pam.d/hyprlock
pkill hyprlock
```

## Catatan per-distro

- **Fedora/RHEL (authselect):** fitur `with-fingerprint` / `with-faillock` diatur
  lewat `authselect`. Ubah `/etc/pam.d/hyprlock` langsung tidak akan
  di-overwrite oleh authselect (beda dengan `system-auth` yang auto-generate,
  jangan edit itu manual).
- **Arch/Omarchy:** kadang `/etc/pam.d/hyprlock` malah nggak ada sama sekali
  (paket hyprlock versi lama belum nyertain), jadi hyprlock gagal auth total.
  Fix di atas juga menyelesaikan kasus ini karena filenya dibuat dari nol.

## Referensi

- https://github.com/Abdullah-Badawy1/community-answers/blob/main/hyprlock-wrong_password_fix.md
- https://github.com/basecamp/omarchy/issues/2094
- https://github.com/hyprwm/hyprlock/issues/499
