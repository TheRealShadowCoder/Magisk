# App developer reference — FXGA custom Magisk

This is a **source navigation map and feature contract**, not a generated API reference or a claim that every source method is remotely callable. It is grounded in the fork's `custom-v32-hide` branch inspected on 2026-11-20.

## Main application components

| Directory/file | Responsibility |
|---|---|
| `app/apk/src/main/java/com/topjohnwu/magisk/ui/MainActivity.kt` | Top-level Android Activity; handles app intents, navigation and dialogs |
| `ui/MainScreen.kt` | Main tabs and content surface |
| `ui/MagiskTheme.kt` | Color schemes, shapes, typography, system bars |
| `ui/navigation/Routes.kt` | Typed navigation keys for Main, DenyList, Flash, SuperuserDetail, SuperuserGrant, Action |
| `ui/home/` | Home/dashboard screen |
| `ui/superuser/` | Superuser permission UI |
| `ui/module/` | Module list, install, action and removal management |
| `ui/settings/` | Manager settings and view model |
| `ui/deny/` | Process exclusion / DenyList configuration |
| `ui/flash/` | Flash/install operations |
| `ui/install/` | Installation assistance |
| `ui/log/` | In-app logging view |
| `ui/terminal/` | Terminal UI |
| `app/core/src/main/java/com/topjohnwu/magisk/core/Config.kt` | Shared settings and preferences |
| `core/Info.kt`, `core/Const.kt` | Runtime state and constants |
| `core/model/module/LocalModule.kt` | Installed module discovery, metadata and enabled/remove state |
| `native/src/core/bootstages.rs` | Native boot lifecycle and Safe Mode |
| `native/src/core/db.rs` | Native SQLite settings |
| `native/src/core/module.rs` | Native module processing |
| `native/src/core/zygisk/` | Native Zygisk implementation |
| `native/src/core/deny/` | Native DenyList logic |
| `native/src/core/su/` | Superuser implementation |
| `native/src/core/logging.rs` | Native logging |
| `native/src/core/selinux.rs` | Native SELinux integration |

These are source code locations. For behavior-level guarantees, read implementations and execute tests on the target commit.

## Settings screen action inventory

The fork's `SettingsViewModel.kt` currently declares these publicly named actions. This list identifies **UI entry points**, not generic ADB RPC methods.

| Group | Verified method names |
|---|---|
| Reload | `refreshEnvironment` |
| Appearance/language | `setColorMode`, `setLanguage` |
| Updates | `setUpdateChannel`, `openCustomChannelUrlDialog`, `saveCustomChannelUrl`, `setCheckUpdate` |
| Connectivity/storage | `setDoh`, `openDownloadPathDialog`, `saveDownloadPath` |
| Package name / Hide app | `setRandomPackageName`, `openHideAppDialog`, `hideApp`, `restoreMagiskApp` |
| Systemless hosts | `createHosts` |
| Zygisk/DenyList | `toggleZygisk`, `toggleDenyList`, `navigateToDenyList` |
| Root/security | `setSuAuth`, `setMultiuserMode`, `setNamespaceMode`, `setNotificationMode`, `setSuRestrict` |
| Dialog lifecycle | `dismissDialog` |

The FXGA module settings screen uses a **separate, internal Activity** launched from the existing Settings screen. This is intentional: it avoids replacing the customized v32 Hide app and Zygisk flows.

## Module architecture

Normal Magisk modules provide `module.prop`, optional startup scripts, and potentially `zygisk/*.so`. `LocalModule.installed()` already enumerates them. Module enablement and removal remain controlled by existing `ModuleViewModel` and `LocalModule`.

The FXGA menu adds a *separate opt-in settings protocol*, documented in [MODULE_PROTOCOL.md](MODULE_PROTOCOL.md). It never assumes that arbitrary `config.sh`, `system.prop` or native binary bytes can be safely rewritten as a settings UI.

### UI interaction contract

1. App loads modules on an IO dispatcher and displays a metadata card for each module.
2. Card opens a menu; app reads an optional JSON schema from the module directory through the approved root shell.
3. If the schema passes validation, the app renders allowed controls.
4. User presses **Save**; all proposed values are validated again.
5. Root shell writes `fxga-settings.conf` atomically with restricted permissions.
6. The module's author decides when/how the module consumes the data, including whether a restart is required.
7. The Activity reports status and logs event metadata without logging values.

### Module author responsibilities

Provide a versioned JSON schema, implement a defensive file reader, test every choice and numeric bound, and describe which actions require a reboot. If a module has no supported schema, the app deliberately shows *details only*.

## Build, signing and release

- Read `AGENTS.md` and the repository's app/native skills.
- Use `python build.py ndk`, then `python build.py all` (toolchain required).
- Run app lint/tests and schema validator; see [ANDROID17_TEST_PLAN.md](ANDROID17_TEST_PLAN.md).
- The custom fork must be signed with its **own release keystore**, never the upstream Magisk key. See `CUSTOM_BUILD.md`.
- Do not merge this draft feature branch until reviewed and tested on a recoverable Android 17 device.

## Diagnostics and ADB

The earlier v3 diagnostic ZIP includes a root-authorized, allowlisted ADB command set, log journal and per-app export. It is **separate** from the currently committed v32 source changes. See [ADB_DIAGNOSTICS.md](ADB_DIAGNOSTICS.md).

Future internal ADB handlers should follow a documented authorization model, typed parameters, explicit allowlists, confirmation for mutations, redaction, and tests; do not expose unrestricted Java/Kotlin reflection, private-data access or raw command execution.

## Reporting a compatibility problem

Record the Android build fingerprint, SDK/API, ABI, Magisk commit, module ID/version, app package/process, timestamp, whether the problem reproduces with other modules disabled, and a **redacted** crash excerpt. State whether the result is **confirmed, suspected or untested**. Keep credentials and private user content out of public GitHub reports.
