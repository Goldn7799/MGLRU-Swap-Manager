#!/system/bin/sh
# Prints status as key=value lines for the WebUI
MODDIR=${0%/*}
. "$MODDIR/common.sh"

find_swap_dev
if [ -n "$SWAPDEV" ]; then echo "swap_active=1"; else echo "swap_active=0"; fi
echo "swap_dev=$SWAPDEV"

FILE_MB=0
[ -f "$SWAPFILE" ] && FILE_MB=$(( $(stat -c %s "$SWAPFILE") / 1048576 ))
echo "file_mb=$FILE_MB"

if [ -d /dev/.swapfile_minttl.lock ]; then echo "busy=1"; else echo "busy=0"; fi

if [ -e "$MINTTL" ]; then echo "min_ttl=$(cat "$MINTTL")"; else echo "min_ttl=n/a"; fi
echo "ttl_default=$(cat "$TTL_DEFAULT_FILE" 2>/dev/null)"
echo "swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)"

echo "mem_total_kb=$(awk '/^MemTotal/{print $2}' /proc/meminfo)"
echo "mem_avail_kb=$(awk '/^MemAvailable/{print $2}' /proc/meminfo)"
echo "data_free_mb=$(df -k /data | tail -1 | awk '{print int($4/1024)}')"

# Effective configuration (after validation)
echo "cfg_enabled=$SWAP_ENABLED"
echo "cfg_size=$SWAP_SIZE_MB"
echo "cfg_prio=$SWAP_PRIORITY"
echo "cfg_swappiness=$SWAPPINESS"
echo "cfg_ttl_disable=$MIN_TTL_DISABLE"
