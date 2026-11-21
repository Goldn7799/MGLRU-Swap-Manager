#!/system/bin/sh
# Shared by service.sh, apply.sh and status.sh.
# The caller must set MODDIR first.

. "$MODDIR/config.sh"
CONF=/data/adb/swapfile_minttl.conf
[ -f "$CONF" ] && . "$CONF"

# Fixed swapfile location, cannot be changed through config
SWAPFILE=/data/adb/swapfile
LOG="$MODDIR/module.log"

MINTTL=/sys/kernel/mm/lru_gen/min_ttl_ms
# Kernel default of min_ttl_ms, recorded once per boot (tmpfs, cleared on reboot)
TTL_DEFAULT_FILE=/dev/.swapfile_minttl.ttl_default

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

isint()  { case "$1" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }
issint() { case "${1#-}" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }

# Validate values, fall back to defaults if they make no sense
case "$SWAP_ENABLED" in 0|1) ;; *) SWAP_ENABLED=1 ;; esac
case "$MIN_TTL_DISABLE" in 0|1) ;; *) MIN_TTL_DISABLE=1 ;; esac
if ! { isint "$SWAP_SIZE_MB" && [ "$SWAP_SIZE_MB" -ge 128 ] && [ "$SWAP_SIZE_MB" -le 65536 ]; }; then
  SWAP_SIZE_MB=2048
fi
if ! { issint "$SWAP_PRIORITY" && [ "$SWAP_PRIORITY" -ge -1 ] && [ "$SWAP_PRIORITY" -le 32767 ]; }; then
  SWAP_PRIORITY=-1
fi
if [ -n "$SWAPPINESS" ]; then
  if ! { isint "$SWAPPINESS" && [ "$SWAPPINESS" -le 200 ]; }; then SWAPPINESS=""; fi
fi

# Record the kernel default of min_ttl_ms if not recorded yet this boot
capture_ttl_default() {
  [ -e "$MINTTL" ] || return 0
  [ -s "$TTL_DEFAULT_FILE" ] && return 0
  cat "$MINTTL" > "$TTL_DEFAULT_FILE" 2>/dev/null
  return 0
}

# Sets SWAPDEV to the active swap device for this swapfile
# (the file itself, or the loop device using it). Empty if inactive.
find_swap_dev() {
  SWAPDEV=""
  if grep -q "$SWAPFILE" /proc/swaps 2>/dev/null; then
    SWAPDEV="$SWAPFILE"
    return 0
  fi
  for L in $(losetup -a 2>/dev/null | grep "$SWAPFILE" | cut -d: -f1); do
    if grep -q "$(basename "$L")" /proc/swaps 2>/dev/null; then
      SWAPDEV="$L"
      return 0
    fi
  done
  return 0
}

# Turn the swapfile off (and detach the loop device if any)
disable_swap() {
  find_swap_dev
  if [ -n "$SWAPDEV" ]; then
    swapoff "$SWAPDEV" >> "$LOG" 2>&1
  fi
  for L in $(losetup -a 2>/dev/null | grep "$SWAPFILE" | cut -d: -f1); do
    losetup -d "$L" >> "$LOG" 2>&1
  done
  return 0
}
