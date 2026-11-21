#!/system/bin/sh
# Usage: apply.sh apply [force] | swapoff | delete
MODDIR=${0%/*}
. "$MODDIR/common.sh"

ACTION=${1:-apply}
FORCE=$2

# Prevent two runs at the same time (/dev is tmpfs, cleared on reboot)
LOCKDIR=/dev/.swapfile_minttl.lock
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  log "Another run is still in progress, aborted"
  exit 1
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
trap 'exit 1' INT TERM HUP

# BusyBox swapon has no -p, so use the system swapon first.
# Priority -1 means automatic: without -p the kernel places it below zram.
do_swapon() {
  if [ "$SWAP_PRIORITY" -ge 0 ]; then
    /system/bin/swapon -p "$SWAP_PRIORITY" "$1" >> "$LOG" 2>&1 && return 0
  fi
  /system/bin/swapon "$1" >> "$LOG" 2>&1 || swapon "$1" >> "$LOG" 2>&1
}

apply_minttl() {
  if [ ! -e "$MINTTL" ]; then
    log "$MINTTL not found (kernel without MGLRU?)"
    return 0
  fi
  capture_ttl_default
  if [ "$MIN_TTL_DISABLE" = "1" ]; then
    echo 0 > "$MINTTL" 2>> "$LOG"
    log "min_ttl_ms turned off, now: $(cat "$MINTTL")"
  elif [ -s "$TTL_DEFAULT_FILE" ]; then
    cat "$TTL_DEFAULT_FILE" > "$MINTTL" 2>> "$LOG"
    log "min_ttl_ms restored to kernel default, now: $(cat "$MINTTL")"
  else
    log "min_ttl_ms left unchanged (kernel default unknown)"
  fi
}

apply_swappiness() {
  if [ -n "$SWAPPINESS" ]; then
    echo "$SWAPPINESS" > /proc/sys/vm/swappiness 2>> "$LOG"
    log "swappiness now: $(cat /proc/sys/vm/swappiness)"
  fi
}

enable_swap() {
  WANT=$((SWAP_SIZE_MB * 1048576))
  HAVE=0
  [ -f "$SWAPFILE" ] && HAVE=$(stat -c %s "$SWAPFILE")
  find_swap_dev

  if [ -n "$SWAPDEV" ] && [ "$HAVE" = "$WANT" ] && [ "$FORCE" != "force" ]; then
    log "Swapfile already active ($SWAPDEV)"
    return 0
  fi

  if [ -n "$SWAPDEV" ]; then
    log "Turning off the active swapfile..."
    disable_swap
    find_swap_dev
    if [ -n "$SWAPDEV" ]; then
      log "FAILED to turn off the old swapfile (not enough RAM to move swapped pages back?)"
      return 1
    fi
  fi

  if [ "$HAVE" != "$WANT" ]; then
    FREE=$(df -k /data | tail -1 | awk '{print int($4/1024)}')
    # the old file will be deleted, so count its size as free space
    FREE=$((FREE + HAVE / 1048576))
    NEED=$((SWAP_SIZE_MB + 512))
    if [ "$FREE" -lt "$NEED" ]; then
      log "Not enough space on /data: need ${NEED}MB, available ${FREE}MB"
      return 1
    fi
    log "Creating ${SWAP_SIZE_MB}MB swapfile, please wait..."
    rm -f "$SWAPFILE"
    # dd instead of fallocate so blocks are really allocated on F2FS
    if ! dd if=/dev/zero of="$SWAPFILE" bs=1048576 count="$SWAP_SIZE_MB" >> "$LOG" 2>&1; then
      log "FAILED to create the swapfile"
      rm -f "$SWAPFILE"
      return 1
    fi
    chmod 600 "$SWAPFILE"
    if ! mkswap "$SWAPFILE" >> "$LOG" 2>&1; then
      log "FAILED mkswap"
      return 1
    fi
    log "Swapfile ready"
  fi

  if do_swapon "$SWAPFILE"; then
    log "swapon succeeded"
  else
    log "Direct swapon failed, trying a loop device"
    LOOP=$(losetup -f 2>> "$LOG")
    if [ -n "$LOOP" ] && losetup "$LOOP" "$SWAPFILE" >> "$LOG" 2>&1 \
       && do_swapon "$LOOP"; then
      log "swapon via $LOOP succeeded"
    else
      log "FAILED to enable swap. See the messages above."
      return 1
    fi
  fi
  return 0
}

case "$ACTION" in
  apply)
    log "== Apply settings${FORCE:+ ($FORCE)} =="
    apply_minttl
    apply_swappiness
    if [ "$SWAP_ENABLED" = "1" ]; then
      enable_swap
    else
      log "Swapfile is disabled in settings"
      [ "$FORCE" = "force" ] && disable_swap
    fi
    ;;
  swapoff)
    log "== Turn off swapfile =="
    disable_swap
    find_swap_dev
    if [ -z "$SWAPDEV" ]; then log "Swapfile turned off"; else log "FAILED to turn off the swapfile"; fi
    ;;
  delete)
    log "== Delete swapfile =="
    disable_swap
    find_swap_dev
    if [ -z "$SWAPDEV" ]; then
      rm -f "$SWAPFILE"
      log "Swapfile deleted"
    else
      log "FAILED: swapfile is still active, not deleted"
    fi
    ;;
  *)
    log "Unknown action: $ACTION"
    ;;
esac
log "Done"
