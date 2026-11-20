#!/system/bin/sh
MODDIR=$(dirname "$0")
[ -e "$MODDIR/disable" ] && exit 0
sh "$MODDIR/fxga_log_service.sh" >/dev/null 2>&1 &
