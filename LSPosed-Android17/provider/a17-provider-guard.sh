#!/system/bin/sh
# Android 17 provider compatibility guard for Vector Zygisk modules.
# Diagnostic/install safety check only: this does not configure root or Zygisk.
# Source this from customize.sh after extracting and SHA-verifying it.

a17_enabled_module() {
    a17_name="$1"
    for a17_root in /data/adb/modules /data/adb/modules_update; do
        a17_dir="$a17_root/$a17_name"
        if [ -f "$a17_dir/module.prop" ] &&
           [ ! -e "$a17_dir/disable" ] &&
           [ ! -e "$a17_dir/remove" ]; then
            return 0
        fi
    done
    return 1
}

a17_module_providers() {
    # Known external Zygisk injectors. ReZygisk's official id is 'rezygisk';
    # zygisksu is used by ZygiskNext / NeoZygisk.
    a17_found=""
    for a17_id in rezygisk zygisksu zygisk_next neozygisk rezygisk_next; do
        if a17_enabled_module "$a17_id"; then
            if [ -n "$a17_found" ]; then
                a17_found="$a17_found,$a17_id"
            else
                a17_found="$a17_id"
            fi
        fi
    done
    printf '%s' "$a17_found"
}

a17_magisk_builtin_state() {
    if ! command -v magisk >/dev/null 2>&1; then
        printf 'not-magisk'
        return
    fi
    a17_setting="$(magisk --sqlite "SELECT value FROM settings WHERE key='zygisk';" 2>/dev/null || true)"
    case "$a17_setting" in
        "value=1"|*"value=1"*) printf 'on' ;;
        "value=0"|*"value=0"*) printf 'off' ;;
        *) printf 'unknown' ;;
    esac
}

# Pure evaluation function so CI can test the provider matrix without Android.
# Arguments: API level, built-in Magisk Zygisk state, comma-separated external
# provider ids. Return 0 supported, nonzero unsupported/unknown; prints reason.
a17_provider_evaluate() {
    a17_sdk="$1"
    a17_builtin="$2"
    a17_external="$3"
    if [ "$a17_sdk" != 37 ]; then
        echo "FAIL: this experimental release requires Android 17 / API 37"
        return 10
    fi
    case "$a17_external" in
        *,*) echo "FAIL: multiple standalone Zygisk providers active: $a17_external"; return 11 ;;
    esac
    if [ "$a17_builtin" = on ] && [ -n "$a17_external" ]; then
        echo "FAIL: Magisk built-in Zygisk conflicts with standalone provider $a17_external"
        return 12
    fi
    if [ "$a17_builtin" = on ]; then
        echo "CONFIGURED: Magisk built-in Zygisk"
        return 0
    fi
    if [ -n "$a17_external" ]; then
        if [ "$a17_builtin" = unknown ]; then
            echo "UNVERIFIED: cannot read Magisk built-in Zygisk state; disable built-in Zygisk first"
            return 13
        fi
        echo "CONFIGURED: standalone $a17_external (must verify hooks on device)"
        return 0
    fi
    echo "UNVERIFIED: no confirmed Zygisk provider; enable built-in Magisk Zygisk or install one standalone provider"
    return 14
}

a17_provider_preflight() {
    # The installer has also sourced a17-provider-control.sh. Source uses
    # the saved user choice, or Auto (default), and stages ONE provider for
    # the NEXT boot. It does not reboot the device.
    # This menu manages Magisk built-in Zygisk or ReZygisk only. A third
    # standalone injector must not remain active with either choice.
    a17_other="$(a17_module_providers)"
    case "$a17_other" in
        ""|rezygisk) ;;
        *)
            ui_print "! Another standalone Zygisk provider is enabled: $a17_other"
            ui_print "! Disable extra standalone injectors before switching."
            return 15 ;;
    esac
    a17_mode="$(a17_choice_read)"
    ui_print "- Android 17 provider preference: $a17_mode"
    a17_result="$(a17_apply "$a17_mode" 2>&1)"
    a17_rc="$?"
    ui_print "- $a17_result"
    if [ "$a17_rc" -ne 0 ]; then
        ui_print "! Could not stage a safe Zygisk provider configuration."
        ui_print "! No framework installation will continue until a provider can be selected."
        return "$a17_rc"
    fi
    ui_print "- Provider staged for the next reboot (no automatic reboot)."
    return 0
}
