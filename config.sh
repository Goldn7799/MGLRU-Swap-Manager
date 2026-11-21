#!/system/bin/sh
# Module defaults.
# User settings are stored in /data/adb/swapfile_minttl.conf
# (edited through the WebUI) and override the values below.

# 1 = create/enable the swapfile at boot, 0 = don't
SWAP_ENABLED=1

# Swapfile size in MB
SWAP_SIZE_MB=1024

# Swap priority. -1 = automatic (kernel places it below zram).
# 0-32767 = manual priority (higher = used first).
SWAP_PRIORITY=-1

# vm.swappiness (0-200). Empty = leave unchanged.
SWAPPINESS=

# 1 = turn off min_ttl_ms (write 0 to /sys/kernel/mm/lru_gen/min_ttl_ms)
# 0 = use the kernel default value
MIN_TTL_DISABLE=1
