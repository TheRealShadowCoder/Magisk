# ADB control and diagnostic logging

## Trust boundary: no open debug backdoor

The earlier FXGA Android 17 v3 diagnostic module (delivered as a separate ZIP) uses this access path:

```text
authorized PC -> adb shell -> explicit Magisk su grant -> allowlisted fxga_diag.sh
                                                       -> Magisk CLI / module state / logs
```

There is **no automatically opened network port, no ADB authorization bypass and no generic reflection/RPC execution of private methods**. This GitHub feature branch does not yet embed that ZIP as part of the APK source.

## v3 diagnostic commands (external installable module)

| Interface | Operations |
|---|---|
| `status` / `health` | Device API, SELinux, Magisk, boot and Zygisk status |
| `modules` / `module-info <id>` | Installed module metadata and module layout |
| `module-enable <id>` / `module-disable <id>` | Next-boot module enable/disable |
| `app <pkg>` / `logs <pkg>` / `trace <pkg>` | Per-app diagnostic evidence |
| `journal` / `audit` | Rotating local events and ADB action records |
| `denylist-list` / `denylist-add` / `denylist-remove` | Explicit root-authorized process exclusion changes |
| `coverage` / `functions` | Real command/telemetry coverage, not a promise of complete introspection |

Examples once the separately supplied v3 module is installed:

```powershell
adb devices
adb shell su -c id
.\windows\FXGA-ADB.ps1 -Action health -ExportZip
.\windows\FXGA-ADB.ps1 -Action module-info -ModuleId example_module
.\windows\FXGA-ADB.ps1 -Action report -Package com.example.app
```

The PowerShell wrapper from the v3 development kit writes report ZIP files to `%USERPROFILE%\Desktop\A52 Report`, leaving no loose report files in that directory. The GitHub feature branch does not include that Windows wrapper; it must be ported or supplied separately.

## New module settings interface

The manager reads `fxga-settings.json` and writes `fxga-settings.conf` when the user explicitly taps **Save**. The current app source does **not** yet expose equivalent schema-validated per-module writes through ADB. Avoid raw `adb shell su -c "echo ... > ..."` for module configuration; that bypasses UI validation and could corrupt module state.

For an eventual ADB interface, implement:

```text
fxga module-config list
fxga module-config schema <module-id>
fxga module-config get <module-id>
fxga module-config set <module-id> <setting-key> <value> --confirm
fxga module-config export <module-id>
```

These are **proposed**, not currently executable commands. Reuse the same schema validator as the Android app, restrict writes to known root-owned paths, log action names without values, and require an explicit root grant plus write confirmation.

## Logging expectations

- Emit bounded event metadata for module scan, schema failure and settings save (module ID and count, not settings values).
- Keep rolling native Zygisk, module load and crash evidence separate from user-facing display state.
- Never continuously log passwords, keystrokes, app text, authentication messages, raw device identifiers or third-party private data.
- Report the module/ABI/API, time, error code and remediation where evidence exists.
- Distinguish `observed`, `suspected`, `unknown` and `not tested`.
- Before sharing ZIPs, inspect and redact raw logcat/crash dumps; keep them private by default.

## Missing pieces

A root authorization decision does not expose every private Kotlin/Rust/C++ method. A universal internal API needs documented command handlers or audited build-time instrumentation per function. There is no reliable static proof that all third-party Zygisk modules function on Android 17.
