#!/system/bin/sh
SWAPFILE=/data/adb/swapfile

swapoff "$SWAPFILE" 2>/dev/null
for L in $(losetup -a 2>/dev/null | grep "$SWAPFILE" | cut -d: -f1); do
  swapoff "$L" 2>/dev/null
  losetup -d "$L" 2>/dev/null
done
rm -f "$SWAPFILE"
rm -f /data/adb/swapfile_minttl.conf /data/adb/swapfile_minttl.conf.tmp
