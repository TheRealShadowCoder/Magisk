#!/system/bin/sh
# Local event-only journal, four files maximum (1 MiB each).
umask 077
ROOT=/data/adb/fxga_diagnostics
LOGS="$ROOT/logs"
mkdir -p "$LOGS" || exit 1
chmod 700 "$ROOT" "$LOGS" 2>/dev/null || true
redact() {
  case "$1" in
    *Authorization:*|*Bearer\ *|*password=*|*access_token*|*refresh_token*|*PRIVATE\ KEY*|*OTP=*|*EAP-AKA*)
      echo '[redacted sensitive event]' ;;
    *) printf '%s\n' "$1" | cut -c1-480 ;;
  esac
}
rotate() {
  [ ! -f "$LOGS/events.2.log" ] || mv -f "$LOGS/events.2.log" "$LOGS/events.3.log"
  [ ! -f "$LOGS/events.1.log" ] || mv -f "$LOGS/events.1.log" "$LOGS/events.2.log"
  [ ! -f "$LOGS/events.0.log" ] || mv -f "$LOGS/events.0.log" "$LOGS/events.1.log"
  : > "$LOGS/events.0.log"; chmod 600 "$LOGS/events.0.log"
}
printf '%s service-start\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$LOGS/events.0.log"
while :; do
  logcat -b main -b system -b crash -v threadtime -T 1 \
    -s FXGAMagisk:V Magisk:V MagiskD:V Zygisk:V zygisk:V AndroidRuntime:E DEBUG:E libc:F '*:S' 2>/dev/null |
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      redact "$line" >> "$LOGS/events.0.log"
      count=$(wc -c < "$LOGS/events.0.log" 2>/dev/null || echo 0)
      [ "$count" -lt 1048576 ] || rotate
    done
  sleep 5
done
