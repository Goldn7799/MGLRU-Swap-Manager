#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/common.sh"

: > "$LOG"

# Record the kernel default of min_ttl_ms before anything changes it
capture_ttl_default

# Wait for boot to finish
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 15

sh "$MODDIR/apply.sh" apply
