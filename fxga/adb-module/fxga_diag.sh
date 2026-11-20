#!/system/bin/sh
# FXGA local allowlisted Magisk diagnostic CLI (Android 17).
# Requires an explicitly approved "adb shell su" session.
set -u
ROOT=/data/adb/fxga_diagnostics
MODROOT=/data/adb/modules
umask 077

fail() { echo "ERROR: $*" >&2; exit 2; }
[ "$(id -u)" = 0 ] || fail "root authorization required"
action="$1"; shift || true

valid_pkg() {
  case "$1" in ''|*[!A-Za-z0-9_.]*) return 1;; *.*) return 0;; *) return 1;; esac
}
valid_process() {
  case "$1" in ''|*[!A-Za-z0-9_.:]*) return 1;; *) return 0;; esac
}
valid_id() {
  case "$1" in ''|.|..|*[!A-Za-z0-9_.-]*) return 1;; *) return 0;; esac
}
check_pkg() { valid_pkg "$1" && pm path "$1" >/dev/null 2>&1 || fail "invalid or missing package"; }
check_module() {
  valid_id "$1" || fail "invalid module id"
  [ -d "$MODROOT/$1" ] && [ ! -L "$MODROOT/$1" ] &&
    [ -f "$MODROOT/$1/module.prop" ] || fail "module missing"
}
help() {
  cat <<'HELP'
FXGA local Android 17 ADB CLI (no network server)
  help / coverage                    command list and coverage
  status / health                    Android, Magisk and Zygisk status
  modules                            installed module list and ABI warnings
  module-info ID                    selected module metadata
  module-schema ID                  opt-in settings schema
  module-settings ID                saved settings (may be private)
  module-enable ID                  re-enable module at next boot
  module-disable ID                 disable module at next boot
  apps                               third-party packages
  app PACKAGE                       package info and crash excerpt
  logs PACKAGE                      package-matching crash evidence
  denylist-list                      existing DenyList
  denylist-add PACKAGE PROCESS       add explicit process
  denylist-remove PACKAGE           remove explicit package
  journal                            rotating local event metadata
  audit                              ADB command audit
  report [PACKAGE]                   combined report
No root bypass or generic invocation of private application methods.
HELP
}
health() {
  echo "timestamp_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "android_api=$(getprop ro.build.version.sdk)"
  echo "android_version=$(getprop ro.build.version.release)"
  echo "device=$(getprop ro.product.device)"
  echo "cpu_abis=$(getprop ro.product.cpu.abilist)"
  echo "boot_complete=$(getprop sys.boot_completed)"
  echo "selinux=$(getenforce 2>/dev/null || echo unknown)"
  echo "magisk=$(magisk -v 2>/dev/null || echo not_found)"
  echo '[zygisk_config]'
  magisk --sqlite "SELECT key,value FROM settings WHERE key='zygisk';" || true
  echo '[denylist]'
  magisk --denylist status || true
}
module_list() {
  cpu=$(getprop ro.product.cpu.abilist)
  for d in "$MODROOT"/*; do
    [ -d "$d" ] && [ -f "$d/module.prop" ] || continue
    id=$(basename "$d")
    echo "MODULE=$id"
    grep -E '^(name|author|version|description)=' "$d/module.prop" | head -n 12 || true
    [ -e "$d/disable" ] && echo "enabled=false" || echo "enabled=true"
    [ -e "$d/zygisk/unloaded" ] && echo 'warning=zygisk_unloaded'
    [ -d "$d/riru" ] && echo 'warning=legacy_riru'
    if [ -d "$d/zygisk" ]; then
      found=0
      for so in "$d"/zygisk/*.so; do
        [ -f "$so" ] || continue
        arch=$(basename "$so" .so)
        echo "zygisk_library=$arch"
        case ",$cpu," in *",$arch,"*) found=1;; esac
      done
      [ "$found" = 1 ] || echo 'warning=missing_native_library_for_device'
    fi
  done
}
app_logs() {
  echo 'Only package-named crash lines are included. Review before sharing.'
  logcat -b crash -d -t 2400 -v threadtime 2>/dev/null |
    grep -F "$1" | tail -n 200 || true
}
app_info() {
  echo "package=$1"
  pm path "$1" | head -n 4
  dumpsys package "$1" 2>/dev/null |
    grep -E 'versionName=|targetSdk=|minSdk=|primaryCpuAbi=' | head -n 20 || true
  app_logs "$1"
}
mkdir -p "$ROOT"
chmod 0700 "$ROOT"
printf '%s action=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$action" >> "$ROOT/audit.log"
chmod 0600 "$ROOT/audit.log"

case "$action" in
  help|coverage) [ "$#" -eq 0 ] || fail "unexpected arguments"; help ;;
  health|status) [ "$#" -eq 0 ] || fail "unexpected arguments"; health ;;
  modules) [ "$#" -eq 0 ] || fail "unexpected arguments"; module_list ;;
  module-info|module-schema|module-settings)
    [ "$#" -eq 1 ] || fail "expected module ID"; check_module "$1"
    case "$action" in
      module-info) f="$MODROOT/$1/module.prop" ;;
      module-schema) f="$MODROOT/$1/fxga-settings.json" ;;
      *) f="$MODROOT/$1/fxga-settings.conf" ;;
    esac
    [ -f "$f" ] && [ ! -L "$f" ] || fail "file not available"
    head -c 65536 "$f" ;;
  module-enable|module-disable)
    [ "$#" -eq 1 ] || fail "expected module ID"; check_module "$1"
    [ "$1" != fxga_adbdiag ] || fail "cannot modify own diagnostic module"
    if [ "$action" = module-enable ]; then rm -f "$MODROOT/$1/disable";
    else touch "$MODROOT/$1/disable"; fi
    echo 'module state changed: reboot to apply' ;;
  apps) [ "$#" -eq 0 ] || fail "unexpected arguments"; pm list packages -3 ;;
  app|logs)
    [ "$#" -eq 1 ] || fail "expected package"; check_pkg "$1"
    if [ "$action" = app ]; then app_info "$1"; else app_logs "$1"; fi ;;
  denylist-list) [ "$#" -eq 0 ] || fail "unexpected arguments"; magisk --denylist ls ;;
  denylist-add)
    [ "$#" -eq 2 ] || fail "package and process required"
    check_pkg "$1"; valid_process "$2" || fail "bad process"
    magisk --denylist add "$1" "$2" ;;
  denylist-remove)
    [ "$#" -eq 1 ] || fail "package required"; check_pkg "$1"
    magisk --denylist rm "$1" ;;
  journal)
    [ "$#" -eq 0 ] || fail "unexpected arguments"
    for f in "$ROOT"/logs/events.*.log; do
      [ ! -f "$f" ] || tail -n 250 "$f"
    done ;;
  audit) [ "$#" -eq 0 ] || fail "unexpected arguments"; tail -n 200 "$ROOT/audit.log" ;;
  report)
    [ "$#" -le 1 ] || fail "optional package only"
    health; module_list
    if [ "$#" -eq 1 ]; then check_pkg "$1"; app_info "$1"; fi ;;
  *) fail "unknown operation: $action" ;;
esac
