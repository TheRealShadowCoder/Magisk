#!/system/bin/sh
# Example consumer for FXGA module settings v1.
# A real module should replace example_module with its actual fixed module ID.
# Read values as DATA. Never source this file as a shell script.
CFG=/data/adb/modules/example_module/fxga-settings.conf
enabled=true
profile=stable
log_level=1

if [ -f "$CFG" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      enabled) case "$value" in true|false) enabled=$value ;; esac ;;
      profile) case "$value" in stable|balanced|debug) profile=$value ;; esac ;;
      log_level) case "$value" in 0|1|2|3) log_level=$value ;; esac ;;
    esac
  done < "$CFG"
fi
printf 'enabled=%s profile=%s log_level=%s\n' "$enabled" "$profile" "$log_level"
