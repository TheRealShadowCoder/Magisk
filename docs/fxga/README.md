# FXGA Magisk — developer documentation

**Project repository:** [TheRealShadowCoder/Magisk](https://github.com/TheRealShadowCoder/Magisk)  
**Base examined:** branch `custom-v32-hide` (custom v32 fork), not the older v31.1 source patcher.  
**Target test device:** Galaxy A52 4G / `a52q`, Android 17 / API 37.  
**Feature branch:** `feature/fxga-module-settings-a17`.

## Scope and status

This fork builds on Magisk. Core Magisk still provides MagiskSU, a native daemon, Zygisk, module loading, boot patching and the Android manager. This branch additionally implements an **FXGA module settings manager**.

Implemented on this branch:
- A **Settings → FXGA module settings** entry in the Compose manager.
- An internal, non-exported Activity that enumerates modules using the existing `LocalModule.installed()` API.
- Per-module metadata: display name, ID, version, author, description, enabled state, Zygisk layout and whether an action script exists.
- An expandable per-module menu. A module that opts in with `fxga-settings.json` receives toggles, choices and bounded integer controls.
- Strict schema/value validation and atomic, root-owned `fxga-settings.conf` writes. No automatic execution of arbitrary module scripts.
- Status/error reporting and event-name-only Android log messages for module scans and setting saves.

**Not yet verified:** compilation with the complete v32 build environment, runtime behavior on Android 17, per-module integration on a real handset, translated UI, or performance with many installed modules. The separate v31.1 FXGA ADB/logging ZIPs created earlier are **not part of this GitHub branch** unless ported separately. Do not confuse source-level implementation with a proven APK.

## Documentation map

| Document | Contents |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | App/native components, data flow, source navigation |
| [MODULE_PROTOCOL.md](MODULE_PROTOCOL.md) | Module author integration, schema, file location, examples |
| [ADB_DIAGNOSTICS.md](ADB_DIAGNOSTICS.md) | ADB security model, logging, evidence exports, current coverage |
| [ANDROID17_TEST_PLAN.md](ANDROID17_TEST_PLAN.md) | API 37 matrix, build instructions, tests and release blockers |
| [SECURITY.md](SECURITY.md) | Threat model, root permissions, path and input validation |

Validate a module settings manifest before distribution:

```sh
python tools/fxga/validate_manifest.py --self-test
python tools/fxga/validate_manifest.py docs/fxga/examples/fxga-settings.json
```

## Essential developer workflow

1. Clone the fork **including submodules** and check out the feature branch.
2. Read [AGENTS.md](../../AGENTS.md) and the repository's `.agents/skills/magisk-app/SKILL.md` before editing.
3. Install the Android SDK, NDK/ONDK, Python and Git using [the upstream build guide](../build.md).
4. Build using the repo build orchestrator: `python build.py all` (from the repository root). On Windows, enable developer mode and symlinks.
5. Run `python build.py test`, then app Gradle lint via `scripts/env.py`. Device/ADB tests are required before calling it compatible.
6. Use a development signing key, **never upstream Magisk's publisher key**. Read [CUSTOM_BUILD.md](../../CUSTOM_BUILD.md).
7. File bug reports with exact build SHA, API, device, module ID and **redacted** logs.

## Contributing

Avoid claiming universal Android 17 compatibility. Mark problems as reproduced, suspected or untested. New module settings types must have a validation rule, safe storage representation, tests, and protocol documentation. Preserve Magisk Safe Mode and never turn the app into an unprotected ADB command server.

The primary upstream reference is [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk); this fork is not the upstream signed release.
