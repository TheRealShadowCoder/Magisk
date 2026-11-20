# Android 17 / API 37 test and release plan

**Target:** Samsung Galaxy A52 4G (\`a52q\`), Android 17, custom Magisk v32 source. A debug build and signed device install must be tested before release.

## Build prerequisites

Use the repository instructions in \`AGENTS.md\`, \`docs/build.md\` and \`CUSTOM_BUILD.md\`. Clone with submodules. On Windows enable developer mode (symlink support), install Android Studio/SDK and JDK, and run:

\`\`\`powershell
python .\build.py ndk
python .\build.py all
python .\build.py test
\`\`\`

Lint or other standalone Gradle commands must run through \`scripts/env.py\`, as required by this repository's agent guidelines. Do not publish unsigned or unverified installer APKs.

## Module manager acceptance tests

| ID | Scenario | Pass criteria |
|---|---|---|
| M01 | No modules | Empty list; no crash |
| M02 | Standard module with only \`module.prop\` | Details visible; no editable controls |
| M03 | Module with valid FXGA manifest | Toggle/select/integer render correctly |
| M04 | Modify and save | Only declared keys written; \`0600\` file permissions |
| M05 | Reopen app | Saved values reload |
| M06 | Invalid schema/key/duplicate choice | Validation warning; no dangerous write |
| M07 | Out-of-range integer | Save disabled/rejected |
| M08 | Module disabled | Details shown; no automatic enabling |
| M09 | Module removed during edit | Save fails without editing other paths |
| M10 | Denied root grant | Friendly error; no partial config write |
| M11 | Symbolic link config target | Save rejected |
| M12 | 100 installed modules | Bounded RAM and responsive scrolling |
| M13 | Module provides \`action.sh\` | Script not auto-executed |
| M14 | Device reboot | No settings loss; normal Magisk recovery preserved |
| M15 | RTL, screen readers, dark mode | Usable labels and correct navigation |

## Android 17 / Zygisk checks

1. Record \`getprop ro.build.version.sdk\`, fingerprint, SELinux status, CPU ABI and Magisk version.
2. Boot with Zygisk enabled and with **zero** third-party Zygisk modules; confirm a stable baseline.
3. Install one known-good module at a time and verify actual library loading, app behavior and reboot stability.
4. Check \`arm64-v8a\` and optional 32-bit module libraries; report missing ABI variants.
5. Compare SELinux AVC denials, app crashes and Zygisk loader logs before suggesting policy changes.
6. Test DenyList exclusions and process restarts without making claims about bypassing app security.
7. Trigger/verify Magisk's emergency Safe Mode; it must remain capable of disabling modules.
8. Verify a full diagnostic ZIP can be collected **with user consent** and that redaction works.
9. Measure app scan latency, idle battery impact and per-module config write overhead.
10. Test upgrade/rollback from the user's current rooted Magisk installation using a backed-up boot image.

## Release blockers

- **No verified APK/NDK build** has been performed in this conversation environment.
- The FXGA v31.1 Zygisk/ADB/telemetry patches are separate from this v32 feature branch until formally ported.
- Need unit tests for JSON parsing, validation, file writes, root denial and malformed modules.
- Need a handset test demonstrating settings are consumed by a real participating module.
- Need QA for data retention, privacy and Android 17 failures by process/module.
- Need a documented rollback procedure and recoverable boot image before flashing.

A module that loads is not automatically compatible with every app. Publish compatibility results with device build, module version, test evidence and date.
