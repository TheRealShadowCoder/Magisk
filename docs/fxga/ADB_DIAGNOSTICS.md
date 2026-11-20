# FXGA Android 17 ADB diagnostics (v4 integration)

The current source branch includes a root-authorized local CLI at `fxga/adb-module/fxga_diag.sh`, a bounded log collector `fxga/adb-module/fxga_log_service.sh` and a Windows ZIP-export wrapper at `fxga/windows/FXGA-ADB.ps1`. The GitHub Actions build packages `FXGA_Android17_ADB_Module.zip` next to the APK.

Each operation requires an authorized ADB connection and explicit Magisk approval of `su`. There is no network daemon, ADB permission bypass, blanket shell executor or unvetted private method invocation. Root access remains under Magisk's existing permissions.

## Commands

```text
status | health | modules | module-info ID | module-schema ID
module-settings ID | module-enable ID | module-disable ID | apps
app PACKAGE | logs PACKAGE | denylist-list | denylist-add PACKAGE PROCESS
denylist-remove PACKAGE | journal | audit | report [PACKAGE]
```

`module-settings` is read-only; writes occur only through the app's schema-validated module settings UI. Shell `module-enable` and `module-disable` change next-boot module state, and DenyList mutations are explicit. Unknown private Kotlin/Rust/C++ functions remain inaccessible until audited handlers are written.

On Windows, from the repo root:

```powershell
.\fxga\windows\FXGA-ADB.ps1 -Action status -ExportZip
.\fxga\windows\FXGA-ADB.ps1 -Action report -Package com.example.app
```

Reports contain selected device/module findings and narrowly selected crash excerpts. Each PC report is a ZIP under `%USERPROFILE%\Desktop\A52 Report`; no loose files are retained there. The app's own compatibility screen exports a ZIP via Android's document picker. **Review reports before sharing:** diagnostic logs can still contain sensitive information despite best-effort filtering.

### Persistent journal

The Magisk module starts a local rotating journal on normal boot (four approximately 1 MiB files), collecting Magisk/Zygisk and crash-error tags. The app's own event log holds only bounded method names and lifecycle events. Neither system claims complete arbitrary-app execution tracing or guaranteed Android 17 compatibility. Safe Mode remains the recovery mechanism.
