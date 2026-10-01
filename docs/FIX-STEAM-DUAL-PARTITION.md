# Fix: Steam Game Won't Launch on Dual-Boot NTFS Partitions

## Symptom

Game installed via Steam + Proton (or Proton-GE) fails to launch. No window
opens, no visible error in the Steam UI.

Example: Persona 3 Reload (AppID `2161700`), library installed on an NTFS
partition shared with Windows.

## Root Cause

Steam library lives on an NTFS partition mounted via `ntfs-3g`/`fuseblk`
without `uid=`/`gid=` mount options. NTFS has no native Unix ownership
metadata, so ntfs-3g falls back to `user_id=0,group_id=0` — every file on
the partition appears **owned by root**, even though permission bits show
`777`.

Wine/Proton explicitly refuses to run if its prefix directory
(`compatdata/<appid>/pfx`) is not owned by the invoking user. This shows up
in the Proton log as:

```
wine: '/mnt/<uuid>/.../compatdata/<appid>/pfx' is not owned by you
```

Check the log with:

```bash
PROTON_LOG=1 %command%   # set as a launch option in Steam
tail -n 100 ~/steam-<appid>.log
```

This is a mount-option problem, not a Proton/game problem — `chown` alone
does **not** fix it permanently, since ownership on NTFS is entirely
determined by the mount's `uid=`/`gid=` options, not real per-file
metadata.

## Fix

Add explicit `uid=`/`gid=` mount options to the affected partition(s) in
`/etc/fstab`, and pin the filesystem type to `ntfs-3g` (instead of `auto`)
so the options are reliably honored.

### Find the affected UUID(s)

```bash
lsblk -f -o NAME,FSTYPE,LABEL,UUID,SIZE,MOUNTPOINT
id   # confirm your uid/gid, typically 1000/1000
```

### Edit `/etc/fstab`

Before:
```
/dev/disk/by-uuid/<UUID> /mnt/<UUID> auto nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=<Name> 0 0
```

After:
```
/dev/disk/by-uuid/<UUID> /mnt/<UUID> ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=<Name> 0 0
```

Apply with:

```bash
sudo cp /etc/fstab /etc/fstab.bak-$(date +%Y%m%d)
sudo sed -i 's|^/dev/disk/by-uuid/<UUID>.*|/dev/disk/by-uuid/<UUID> /mnt/<UUID> ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=<Name> 0 0|' /etc/fstab

# close Steam completely first
sudo umount /mnt/<UUID>
sudo mount -a
```

### Or via GNOME Disks (GUI)

1. Select the disk → gear icon → **Edit Mount Options**.
2. Turn off **User Session Defaults**.
3. Set **Filesystem Type** from `auto` to `ntfs-3g`.
4. Append to the **Mount Options** field:
   `,uid=1000,gid=1000,dmask=022,fmask=133`
5. Click **OK**, authenticate.
6. Unmount/remount the drive (eject then remount, or reboot) for changes
   to take effect.

## Verification

```bash
findmnt /mnt/<UUID>
# OPTIONS should include uid=1000,gid=1000

ls -ld /mnt/<UUID>/.../compatdata/<appid>/pfx
# owner should be your user, not root
```

## Notes

- Safe for dual-boot: `uid=`/`gid=`/`dmask=`/`fmask=` are Linux-side mount
  presentation only — they don't touch on-disk NTFS metadata or Windows
  ACLs. Windows is unaffected.
- If `mount -a` / GUI remount fails with "Windows is hibernated, refused to
  mount", disable **Fast Startup** in Windows (Control Panel → Power
  Options) and do a full restart (not just shutdown) from Windows once,
  then retry.
- Repeat the same fix for every NTFS partition used as a Steam library or
  Proton prefix location — each is independently affected.

## This machine (reference)

| Drive label | UUID | Mount point | Fixed |
|---|---|---|---|
| Data II | `126011126010FDE3` | `/mnt/126011126010FDE3` | ✅ (holds P3R / AppID 2161700) |
| Data | `BA502F8C502F4F07` | `/mnt/BA502F8C502F4F07` | ✅ |
