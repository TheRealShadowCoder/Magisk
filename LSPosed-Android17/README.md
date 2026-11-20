# LSPosed-derived Vector for Android 17 (API 37) — developer worktree

> **Candidate / not certified**. This branch builds pinned Vector, NOT a fully
> ported LSPosed 1.9.2. All build outputs require Android 17 device tests.

Build source: `JingMatrix/Vector` at `6f6b976e3315c158d501f743c3c609e80cae7ec8`.
Changes applied through the **GitHub Actions workflow**, not committed as a
copy of the full upstream code.

## Applied in CI (candidate fixes)

| Scope | Source change | Reported issue | Validation |
|---|---|---|---|
| Module manager | Reject stale concurrent package scan results; keep last known good list on enumeration failure | [Vector #1099](https://github.com/JingMatrix/Vector/issues/1099) | Source-hunk match only, Android 17 test pending |
| Daemon package enumeration | Throw on unavailable PackageManager rather than returning a false successful empty list | [Vector #1099](https://github.com/JingMatrix/Vector/issues/1099) | Source-hunk match only, Android 17 test pending |
| Scope list | Retain a package when component lookup fails; unknown is not proof of zero hookable processes | [Vector #1098](https://github.com/JingMatrix/Vector/issues/1098), [#1089](https://github.com/JingMatrix/Vector/issues/1089) | **Partial** mitigation, cloned profile enumeration still unresolved |
| Module generations | Evict obsolete ModuleAppService references as modules are replaced, based on upstream PR #1024 | [Vector #1023](https://github.com/JingMatrix/Vector/issues/1023) | Source-hunk match only, repeated updates test pending |

Actual patch files: `patches/1024-module-generation-leak.patch`,
`patches/1099-manager-discovery-consistency.patch`,
`patches/1099-fail-closed-on-missing-package-manager.patch`.

CI runs `git apply --check` on every patch, compiles native/manager components,
validates ZIP entries, SHA-256 and ELF page alignment, and verifies APK signatures.
The API 37 source assertions are in `ci_assert_port.py`.
The optional source test report does **not** certify the device.

## Reported Android 17 issues NOT fixed by these patches

- **Late root / system_server attachment**: Vector #1088, #996. Includes
  Samsung One UI 9 and HyperOS 4-specific injection failures; do not auto-restart
  zygote/system_server or install system-service overlays on the A52.
  Upstream PR #1017 is a large, unmerged candidate. Independent proof required.
- **GrapheneOS manager security policy**: Vector #997. A standalone manager
  can be tested without globally weakening ptrace protections. Upstream PR #1019
  changes host-specific policies and must be reviewed before inclusion.
- **Cloned user/profile discovery**: Vector #1098. Component lookup fallback
  cannot discover an Android profile absent from `IUserManager.getUsers()`.
  Need real user IDs, profile types, and package-manager inventory.
- **ART + Frida/JVMTI**: Vector #980. Needs native crash reproducer and ART
  build ID; no justified low-risk universal patch exists.
- **Zygisk providers / device-specific native injection**: NeoZygisk #132,
  #154, #162; ZygiskNext #135. Fix in the provider/relevant OEM integration,
  not by editing the Vector manager.
- **Compiler-wrapper recursion and daemon recovery**: Vector #1039, #1015
  (cross-version). Upstream PRs #1008 and #1017 remain experimental and must
  undergo controlled failure recovery and bootloop-safety tests.
- **Older Android 17 upstream reports closed**: API 37 Binder change #741,
  package manager #789, LSPlant #189, reoptimization #737, legacy modules
  #817/#1054 and others. Closed does not mean every device validated.

## Mandatory Android 17 release tests (all pending)

1. Compile from pinned source with full recursive submodules; preserve logs.
2. Verify SDK 37 runtime and 16 KiB-compatible ELF alignment.
3. Verify Magisk/Zygisk provider sees the Vector module and daemon starts.
4. Confirm `system_server` injection and manager launch without repeated reboots.
5. Enumerate packages across regular, cloned, secondary and private profiles.
6. Repeat 30 manual manager refreshes and ensure the module count does not drift.
7. Enable harmless test legacy/modern modules in a noncritical test app;
   verify method hook executes and scope updates survive restart.
8. Update a module 10 times, measure daemon ashmem FDs and resident memory;
   verify counts stabilize rather than grow by each APK's DEX count.
9. Reboot 5 times with Zygisk+Vector only; check no crash/tombstone and
   recoverability with root modules disabled.
10. Test Android 17 LineageOS 24.0 A52 separately from Samsung One UI,
    Xiaomi HyperOS and GrapheneOS; never infer OEM parity.

**Pass conditions:** no unexplained restarts/bootloops, manager correctly reports
module contents, a real test hook works in a selected app, and regression tests
pass. A successful APK signature test is insufficient.

To request a build, open GitHub Actions in this repo and run
`Build and validate Android 17 Xposed framework (Vector)` on branch
`lsposed-android17-build`. Do not flash a failing or untested artifact over
a working framework; first ensure ADB/recovery access and disable the older
LSPosed module.

## Magisk built-in Zygisk / PerformanC ReZygisk (Android 17)

Installation now includes a safety gate (source: [provider/README.md](provider/README.md))
which checks API 37 and prevents **confirmed concurrent injector configurations**:

- Magisk with built-in Zygisk enabled and ReZygisk disabled.
- Magisk with built-in Zygisk disabled and ReZygisk enabled.
- KernelSU/APatch with ReZygisk enabled and no other standalone injector.

The guard never toggles root settings. It fails closed if it detects conflicting
providers, and warns when Magisk's built-in setting cannot be verified.
There are nine provider-matrix unit tests run in GitHub Actions.

**Still unresolved:** [ReZygisk Android 17 zygote_next #374](https://github.com/PerformanC/ReZygisk/issues/374),
live hook execution, daemon/system-server registration and three repeated
boot stability tests **for each provider separately**. Two providers must not
both inject Zygote; a single framework module supports *either* one.

For diagnostics run `provider/Run-A52-A17-Zygisk-ReZygisk-Audit.ps1`
from Windows. It creates one ZIP inside `C:\Users\skbus\Desktop\A52 Report`.
