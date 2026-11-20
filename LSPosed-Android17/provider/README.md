# Android 17 (API 37) — Zygisk provider compatibility

**Branch:** `TheRealShadowCoder/Magisk:lsposed-android17-build`  
**Framework source:** pinned Vector `6f6b976e3315c158d501f743c3c609e80cae7ec8` (LSPosed-derived).  
**Certification:** Experimental; no Android 17 device hook tests have passed in this branch.

## What is implemented

- A single Android 17 Vector module intended to use the standard Zygisk API with
  **either** Magisk built-in Zygisk **or** PerformanC ReZygisk.
- Installation guard checks device API 37, Magisk built-in Zygisk setting when readable,
  and enabled external injector module directories (including `rezygisk` and `zygisksu`).
- Explicitly rejects confirmed double-provider configurations to reduce Zygote conflicts.
- Does **not** enable/disable Zygisk, alter Magisk settings, toggle ReZygisk, patch
  SELinux, change boot properties, or reboot the device.
- Guard is packaged and SHA-verified before installer runs it; shell syntax
  and an offline nine-scenario provider matrix are checked in CI.
- ReZygisk is an injection **provider**, not an Xposed module; its provider state
  alone does NOT prove that Vector loaded a hook.

## Supported configuration *intents* — device testing still required

| Root environment | Built-in Magisk Zygisk | ReZygisk | Expected provider mode |
|---|---|---|---|
| Magisk Android 17 | On | Disabled | Magisk built-in |
| Magisk Android 17 | Off | Enabled | ReZygisk |
| KernelSU Android 17 | N/A | Enabled | ReZygisk |
| APatch Android 17 | N/A | Enabled | ReZygisk |
| Magisk Android 17 | On | Enabled | **Reject; conflicts** |
| Any | N/A | ReZygisk + another standalone provider | **Reject; conflicts** |

A ReZygisk module may report running while all injected modules still fail to
work: [PerformanC/ReZygisk #408](https://github.com/PerformanC/ReZygisk/issues/408)
is an example (on Android 16). Android 17 Beta 3 Zygisk failure was reported
as [#318](https://github.com/PerformanC/ReZygisk/issues/318).
More importantly, support for `zygote_next` is an **open Android 17 request**:
[#374](https://github.com/PerformanC/ReZygisk/issues/374).
On a ROM where the injector cannot attach to that Zygote variant, this Vector
module alone cannot fix ReZygisk. Do not bypass its security policies.

Official upstream instructions:
https://github.com/PerformanC/ReZygisk — Magisk built-in Zygisk must be OFF
when using ReZygisk.

## Testing the actual Android 17 hooks

For **each** provider mode on Android 17, with only that provider and Vector enabled:

1. Record Android API 37, ROM version, root manager, provider version.
2. Reboot, verify provider monitor and Zygote injection *actually* running.
3. Run `/data/adb/modules/zygisk_vector/cli status` with root; verify
   `system_server` injection, daemon and manager operation.
4. Install a harmless Xposed test module with one target app and verify a
   method callback executes in the target app (do not infer from manager badge).
5. Test enable/disable of scope, manager module discovery, native errors.
6. Reboot at least three times; watch for Zygote SIGILL, SIGSEGV, SELinux
   denial, daemon death, and boot loops. Make recovery available.
7. Repeat with the *other* provider after disabling the first. Never run both
   providers at once; do not switch providers without rebooting.

The PowerShell audit script is read-only and writes one ZIP with all findings to
`C:\Users\skbus\Desktop\A52 Report` on the Windows PC. It cannot substitute
for a real module hook test, and reports may contain device identifiers/logs.

## Artifacts

- `a17-provider-guard.sh`: source guard copied into the packaged Zygisk module
- `test-provider-matrix.sh`: nine-scenario offline shell unit test
- `Run-A52-A17-Zygisk-ReZygisk-Audit.ps1`: Windows read-only diagnostics
- `../patches/1110-android17-zygisk-provider-guard.patch`: installer integration
- `../../.github/workflows/build-lsposed-android17.yml`: automatic GitHub build

**No evidence of successful patched release compilation or Android 17 runtime
certification has been established yet.** Treat the previous APK as an older
unpatched binary.
