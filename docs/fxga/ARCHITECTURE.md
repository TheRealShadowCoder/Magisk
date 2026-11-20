# Architecture — custom Magisk fork

## Source map (verified against \`custom-v32-hide\`)

\`\`\`text
Magisk/
  app/
    apk/src/main/java/com/topjohnwu/magisk/
      ui/settings/SettingsScreen.kt        # Settings navigation
      ui/module/ModuleScreen.kt             # Existing module list/actions
      ui/module/ModuleViewModel.kt          # Existing module enable/remove
      ui/module/FxgaModuleSettingsActivity.kt # New FXGA module settings UI
    core/src/main/java/com/topjohnwu/magisk/core/
      model/module/LocalModule.kt           # Root-backed module discovery
  native/
    src/core/                                # magiskd, db, boot stages, Zygisk integration
  docs/fxga/                                 # This feature's public developer contract
  .github/workflows/                         # Custom build orchestration
  CUSTOM_BUILD.md                            # Signing and build notes for fork
\`\`\`

## Data flow

\`\`\`text
SettingsScreen
    |
    +--> internal FxgaModuleSettingsActivity
            |
            +--> LocalModule.installed() [existing Magisk API]
            |       |
            |       +--> metadata, enabled/disabled, action/zygisk presence
            |
            +--> root-authorized read (Shell.cmd)
            |       +--> /data/adb/modules/<id>/fxga-settings.json
            |       +--> /data/adb/modules/<id>/fxga-settings.conf
            |
            +--> UI: toggle / select / bounded integer
                    |
                    +--> validate current values against manifest
                    +--> root-authorized atomic write: fxga-settings.conf
                    +--> module's own code reads the saved data when it chooses
\`\`\`

## Trust boundaries

Android app UI is not a privileged root process by itself. Magisk's approved root shell performs reads/writes into protected module directories. Values are validated in Kotlin, and the Activity is \`android:exported="false"\`; no third-party intent can call this settings screen directly.

The module manifest is treated as **data**, not as executable code. A Zygisk module's native libraries continue loading through Magisk core, not through the new settings Activity.

## Relationship to previous FXGA kits

Previous conversations produced stand-alone ZIPs targeting Magisk **v31.1**, including:
- Zygisk normal-boot persistence with Safe Mode preservation.
- An Android 17 compatibility dashboard.
- A root-authorized diagnostic/ADB module and a rotating journal.
- Per-app diagnostic ZIP export.

**Those ZIPs are not automatically merged into this custom v32 GitHub branch.** Their source transformations require code review and an explicit port. The current feature specifically adds per-module settings, not a promise that every native v31.1 patch applies cleanly to v32.

## Next architectural milestones

1. Move the protocol data classes and validation into app \`:core\` with unit tests.
2. Add a secure ADB command for schema-inspected module config editing, sharing the exact Kotlin validation rules.
3. Expose per-module health, last error and redacted ZIP export in the UI.
4. Add live Zygisk module load status via native diagnostic events, without collecting sensitive application data.
5. Add default-language string resources/translations and accessibility audits.
