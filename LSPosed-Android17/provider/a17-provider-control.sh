#!/system/bin/sh
# Android 17 / API 37 Vector Zygisk provider controller.
# Selects ONE injection provider for NEXT boot; it never restarts Zygote.
# Usage: status | select auto|magisk|rezygisk | apply-saved
A17_HOME=/data/adb/vector-provider
A17_CHOICE=$A17_HOME/choice
A17_BOOT=$A17_HOME/pending-boot-id
A17_PROMPT=$A17_HOME/offer-provider-choice
A17_RZ=/data/adb/modules/rezygisk
A17_RZ_NEXT=/data/adb/modules_update/rezygisk

a17_magisk_bin() {
  # A stale Magisk binary on a KernelSU install is not a functioning provider.
  a17_candidate=""
  if command -v magisk >/dev/null 2>&1; then a17_candidate="$(command -v magisk)"
  elif [ -x /data/adb/magisk/magisk ]; then a17_candidate=/data/adb/magisk/magisk
  fi
  [ -n "$a17_candidate" ] || return 1
  "$a17_candidate" -v >/dev/null 2>&1 || return 1
  echo "$a17_candidate"
}
a17_magisk_state() {
  a17_bin="$(a17_magisk_bin)" || { echo absent; return; }
  a17_sql="$("$a17_bin" --sqlite "SELECT value FROM settings WHERE key='zygisk';" 2>/dev/null)" || { echo unknown; return; }
  case "$a17_sql" in
    *"value=1"*) echo on ;;
    *"value=0"*) echo off ;;
    *) echo unknown ;;
  esac
}
a17_rz_installed() {
  [ -f "$A17_RZ/module.prop" ] || [ -f "$A17_RZ_NEXT/module.prop" ]
}
a17_rz_enabled() {
  for a17_dir in "$A17_RZ" "$A17_RZ_NEXT"; do
    if [ -f "$a17_dir/module.prop" ] && [ ! -e "$a17_dir/disable" ] &&
       [ ! -e "$a17_dir/remove" ]; then return 0; fi
  done
  return 1
}
a17_choice_read() {
  if [ -f "$A17_CHOICE" ]; then
    IFS= read -r a17_saved < "$A17_CHOICE"
    case "$a17_saved" in auto|magisk|rezygisk) echo "$a17_saved"; return ;; esac
  fi
  echo auto
}
a17_has_magisk() {
  # Magisk v31.0 is the first version with Android 17 / API 37 Zygisk hooks.
  # -V emits the numeric versionCode (31000 for 31.0, 31100 for 31.1).
  a17_bin="$(a17_magisk_bin)" || { echo no; return; }
  a17_code="$("$a17_bin" -V 2>/dev/null)" || { echo no; return; }
  case "$a17_code" in ""|*[!0-9]*) echo no; return ;; esac
  if [ "$a17_code" -ge 31000 ] && [ "$(a17_magisk_state)" != unknown ]; then
    echo yes
  else
    echo no
  fi
}
a17_has_rz() { a17_rz_installed && echo yes || echo no; }
a17_resolve() {
  case "$1" in
    auto)
      if [ "$2" = yes ]; then echo magisk
      elif [ "$3" = yes ]; then echo rezygisk
      else echo none; return 21
      fi ;;
    magisk)
      [ "$2" = yes ] || { echo none; return 22; }
      echo magisk ;;
    rezygisk)
      [ "$3" = yes ] || { echo none; return 23; }
      echo rezygisk ;;
    *) echo none; return 20 ;;
  esac
}
a17_bootid() { cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown; }
a17_status() {
  a17_builtin="$(a17_magisk_state)"
  a17_rz=absent
  if a17_rz_installed; then
    a17_rz=disabled
    if a17_rz_enabled; then a17_rz=enabled; fi
  fi
  a17_mode="$(a17_choice_read)"
  a17_effective="$(a17_resolve "$a17_mode" "$(a17_has_magisk)" "$(a17_has_rz)" 2>/dev/null)" || a17_effective=none
  a17_conflict=no
  [ "$a17_builtin" = on ] && [ "$a17_rz" = enabled ] && a17_conflict=yes
  a17_prompt=no
  [ -f "$A17_PROMPT" ] && a17_prompt=yes
  a17_pending=no
  if [ -f "$A17_BOOT" ]; then
    IFS= read -r a17_before < "$A17_BOOT"
    [ "$a17_before" = "$(a17_bootid)" ] && a17_pending=yes
  fi
  printf 'mode=%s\neffective=%s\nbuiltin=%s\nrezygisk=%s\nconflict=%s\nchoice_prompt=%s\nreboot_required=%s\n' \
    "$a17_mode" "$a17_effective" "$a17_builtin" "$a17_rz" "$a17_conflict" "$a17_prompt" "$a17_pending"
}
a17_magisk_set() {
  a17_value="$1"
  a17_bin="$(a17_magisk_bin)" || return 1
  "$a17_bin" --sqlite "INSERT OR REPLACE INTO settings (key,value) VALUES ('zygisk',$a17_value);" >/dev/null 2>&1 || return 1
  a17_expected=off
  [ "$a17_value" = 1 ] && a17_expected=on
  [ "$(a17_magisk_state)" = "$a17_expected" ]
}
a17_mark_rz() {
  for a17_dir in "$A17_RZ" "$A17_RZ_NEXT"; do
    [ -f "$a17_dir/module.prop" ] || continue
    [ -f "$a17_dir/remove" ] && continue
    if [ "$1" = disable ]; then
      touch "$a17_dir/disable" || return 1
    else
      rm -f "$a17_dir/disable" || return 1
    fi
  done
}
a17_restore_markers() {
  if [ -f "$A17_RZ/module.prop" ]; then
    if [ "$1" = yes ]; then touch "$A17_RZ/disable"; else rm -f "$A17_RZ/disable"; fi
  fi
  if [ -f "$A17_RZ_NEXT/module.prop" ]; then
    if [ "$2" = yes ]; then touch "$A17_RZ_NEXT/disable"; else rm -f "$A17_RZ_NEXT/disable"; fi
  fi
}
a17_apply() {
  a17_mode="$1"
  [ "$(getprop ro.build.version.sdk 2>/dev/null)" = 37 ] || {
    echo "error=Android 17 API 37 required"; return 30;
  }
  a17_magisk="$(a17_has_magisk)"
  a17_magisk_present=no
  a17_magisk_bin >/dev/null 2>&1 && a17_magisk_present=yes
  a17_target="$(a17_resolve "$a17_mode" "$a17_magisk" "$(a17_has_rz)")"
  a17_rc=$?
  [ "$a17_rc" -eq 0 ] || { echo "error=selected provider unavailable"; return "$a17_rc"; }
  # Check persistence before making any root-provider changes. All files remain
  # root-owned and are never readable by third-party applications.
  umask 077
  mkdir -p "$A17_HOME" || { echo "error=cannot create provider preferences"; return 36; }
  chmod 0700 "$A17_HOME" || return 36
  touch "$A17_HOME/.write-check" || { echo "error=provider preference path readonly"; return 36; }
  rm -f "$A17_HOME/.write-check"
  a17_old="$(a17_magisk_state)"
  if [ "$a17_magisk_present" = yes ] && [ "$a17_old" = unknown ]; then
    echo "error=Magisk database is unreachable; cannot safely select an injector"
    return 31
  fi
  a17_prompt_needed=no
  if [ "$2" = installer ] && [ "$a17_mode" = auto ] && [ "$a17_old" = on ] && a17_rz_enabled; then
    a17_prompt_needed=yes
  fi
  [ "$a17_old" != unknown ] || { echo "error=Magisk Zygisk state unknown"; return 31; }
  a17_old_current=no
  a17_old_next=no
  [ -e "$A17_RZ/disable" ] && a17_old_current=yes
  [ -e "$A17_RZ_NEXT/disable" ] && a17_old_next=yes

  if [ "$a17_target" = magisk ]; then
    # Disable the standalone provider before staging built-in Zygisk.
    if ! a17_mark_rz disable; then
      a17_restore_markers "$a17_old_current" "$a17_old_next"
      echo "error=failed to disable ReZygisk"; return 32
    fi
    if [ "$a17_old" != on ]; then
      if ! a17_magisk_set 1; then
        a17_restore_markers "$a17_old_current" "$a17_old_next"
        echo "error=failed to enable Magisk Zygisk; module state rolled back"; return 33
      fi
    fi
  else
    if [ "$a17_magisk_present" = yes ] && [ "$a17_old" != off ]; then
      if ! a17_magisk_set 0; then
        echo "error=failed to disable built-in Zygisk"; return 34
      fi
    fi
    if ! a17_mark_rz enable; then
      if [ "$a17_magisk_present" = yes ] && [ "$a17_old" = on ]; then a17_magisk_set 1 >/dev/null 2>&1; fi
      a17_restore_markers "$a17_old_current" "$a17_old_next"
      echo "error=failed to enable ReZygisk; rollback attempted"; return 35
    fi
  fi
  printf '%s\n' "$a17_mode" > "$A17_CHOICE.tmp" || return 36
  if ! mv -f "$A17_CHOICE.tmp" "$A17_CHOICE"; then
    # Preference commit failed after provider staging. Undo what we can.
    if [ "$a17_magisk_present" = yes ]; then
      case "$a17_old" in on) a17_magisk_set 1 >/dev/null 2>&1 ;; off) a17_magisk_set 0 >/dev/null 2>&1 ;; esac
    fi
    a17_restore_markers "$a17_old_current" "$a17_old_next"
    echo "error=provider choice was not saved; previous provider restored where possible"
    return 36
  fi
  a17_bootid > "$A17_BOOT"
  if [ "$2" = installer ]; then
    if [ "$a17_prompt_needed" = yes ]; then touch "$A17_PROMPT"; fi
  else
    # The user has made a choice in the manager, including choosing Auto.
    rm -f "$A17_PROMPT"
  fi
  echo "staged=$a17_target"
  a17_status
}
if [ "x$A17_SOURCE_ONLY" != x1 ]; then
  case "$1" in
    status) a17_status ;;
    select) a17_apply "$2" ;;
    apply-saved) a17_apply "$(a17_choice_read)" installer ;;
    *) echo "error=usage: status|select auto|magisk|rezygisk|apply-saved"; exit 2 ;;
  esac
fi
