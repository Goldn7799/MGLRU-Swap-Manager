#!/system/bin/sh
ui_print "- Swapfile + Disable min_ttl_ms v2.1"
ui_print "- Change settings in the WebUI (KernelSU Next > Modules > WebUI)"
ui_print "- Existing settings in /data/adb/swapfile_minttl.conf are kept"
ui_print "- Reboot once so the kernel default of min_ttl_ms gets recorded"

if [ -e /sys/kernel/mm/lru_gen/min_ttl_ms ]; then
  ui_print "- MGLRU detected, min_ttl_ms is available"
else
  ui_print "! lru_gen/min_ttl_ms not found on this kernel"
fi

AVAIL=$(df -k /data | tail -1 | awk '{print int($4/1024)}')
ui_print "- Free space on /data: ${AVAIL}MB"

set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in service.sh apply.sh status.sh common.sh config.sh uninstall.sh; do
  set_perm "$MODPATH/$f" 0 0 0755
done
