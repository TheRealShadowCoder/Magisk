# FXGA module settings security model

## Assets and adversaries

The Android manager is user-facing; the native Magisk daemon and module files run with root privileges. Module developers may intentionally supply malformed metadata. Installed modules themselves already have substantial privileges, so the UI must not increase exposure to unrelated apps, unauthenticated ADB clients or accidental destructive operations.

## Implemented controls

1. The settings Activity is declared \`android:exported="false"\`; it is entered from the existing Magisk Settings screen.
2. Module names and descriptions are **display data**; only validated module directory IDs are used in constructed file paths.
3. Manifest version, field count, unique keys, supported types, options, numeric ranges and defaults are checked before controls render.
4. Only \`toggle\`, \`select\` and \`integer\` types are writable; free-form shell snippets, commands and arbitrary file paths are not supported.
5. Before saving, each value is checked **again** against the currently displayed schema. Input is encoded as Base64 for transport to a fixed root shell command.
6. The generated file is replaced using a temporary file, \`umask 077\`, and mode \`0600\`; the app refuses to write through symbolic links at the fixed destination.
7. Root writes use Magisk's existing \`Shell.cmd\` mechanism; no \`adb tcpip\` activation, background network server, automatic root grant or SELinux bypass is introduced.
8. Module-supplied \`action.sh\`, WebUI and arbitrary executables are never run by the new settings screen.
9. Activity logs record operation name, module ID, count and success/failure only; **not user-selected setting values**.

## Limitations requiring review

- A module with root execution rights can itself modify its files; these checks are not a sandbox against malicious root modules.
- The implementation uses the device's available \`base64 -d\` shell utility; test this on the target Android 17 build.
- The generated file's consumer (the module) must validate data again; never shell-\`source\` the config blindly.
- Atomic replacement reduces partial writes but does not guarantee module-level hot reload or fix a module crash.
- Full app crashes, native crashes and logcat reports may still contain personal data; export only after user action.
- A trusted, custom-signed manager and corresponding Magisk core are required for a production build, following the fork's signing docs.
- Protect bootloop/safe-mode recovery, DenyList semantics and Magisk signature checks through the Android 17 port.

## Vulnerability reporting

Use a private security disclosure channel when possible. Provide sanitized reproduction steps, specific commit SHA, Magisk/Android versions, module ID and logs without credentials or user data. Do not post private keys or unredacted crash dumps in a public issue.
