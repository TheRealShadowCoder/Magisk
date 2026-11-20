# FXGA Magisk v32 + Vector (LSPosed-derived) on Android 17

This compatibility work is based on `TheRealShadowCoder/Magisk:custom-v32-hide`
and `JingMatrix/Vector` pinned at `6f6b976e3315c158d501f743c3c609e80cae7ec8`.
It is **not** a certified fully working Android 17 module until tested on a device.

## Grounded ABI compatibility

* Magisk's native public `native/src/core/zygisk/api.hpp` declares API **5**.
* Magisk's `native/src/core/zygisk/module.cpp` accepts module API 4.
* Vector's native `zygisk/src/main/cpp/include/zygisk.hpp` declares API **4**.
* Vector packages a Magisk module under ID `zygisk_vector`; its per-ABI
  Zygisk libraries use the standard `zygisk/<ABI>.so` layout.
* Therefore the **Zygisk loader API is compatible** at the source-interface
  level. This does not certify native ART hook behavior on Android 17.

## Magisk custom fork normal-boot override

The existing custom Magisk v32 core unconditionally writes `zygisk=1`
in `post_fs_data`. An LSPosed provider manager that only writes `zygisk=0`
would report a false switch to ReZygisk: the next boot restores built-in Zygisk.

The candidate patch on `feature/vector-android17-zygisk-interop` changes
that one decision:

1. **Normal / Auto / Magisk:** retain the original normal-boot always-on
   built-in Zygisk behavior.
2. **Explicit ReZygisk selection:** only if `/data/adb/vector-provider/choice`
   contains exactly `rezygisk` AND an installed enabled ReZygisk module
   is present, set `zygisk=0` and `zygisk_enabled=false` before loading modules.
3. **Missing/disabled ReZygisk:** revert to built-in Zygisk automatically.
4. **Safe Mode:** original emergency path still runs **before** the provider
   decision; it disables modules and Zygisk to protect boot recovery.
5. **Capability handshake:** patched Magisk writes the current boot ID into
   `/data/adb/vector-provider/magisk-provider-aware-boot-id`.
   Vector's root provider controller checks this marker when selecting
   ReZygisk on the FXGA fork. A stale old-fork marker must not pass.
6. No Zygote/system_server restart occurs when selecting providers in the
   manager. Changes take effect on the next reboot.

The provider settings menu lives in **Vector Manager → System status → Zygisk
provider**, not in Magisk core's generic module editor. The Magisk FXGA
`fxga-settings.json` schema is intentionally *not* used as a second,
unsynchronized provider preference.

## Installation and validation

The actual `Vector-v*-Release.zip` is the **Magisk module** to install.
`manager.apk` inside that ZIP is the Vector settings UI. It is not a
substitute for flashing the module ZIP, and it is not the Magisk app itself.

Prior to flashing Magisk or Vector, preserve the currently working boot image
and a recovery route; use the custom Magisk build with its own signing key.
Validate a build on the Galaxy A52 `a52q`, Android 17/API 37:

* Baseline Magisk v32 boot with no third-party injectors.
* Flash Vector module ZIP using custom Magisk module installer. Confirm its
  enabled module ID is `zygisk_vector`.
* Magisk Zygisk-only mode: reboot; confirm daemon + real Xposed hook in a test app.
* ReZygisk-only mode: confirm the provider-aware Magisk build is actually in
  use, select ReZygisk in Vector settings, reboot, then verify the Magisk
  daemon did not force built-in Zygisk back ON and real hooks load.
* Reboot repeatedly, verify Safe Mode / rescue still works, and check
  native crashes/tombstones. Incompatible Android 17 `zygote_next` remains
  possible and depends on the ReZygisk release.
* Test upgrading/removing ReZygisk: Magisk's built-in Zygisk must become the
  safe default again.
* Collect user-approved logs inside a single ZIP under
  `C:\Users\skbus\Desktop\A52 Report`.

A successful GitHub build is a prerequisite but does not prove runtime.
No production release should claim fully compatible until the phone tests pass.
