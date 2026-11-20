# Custom v32 GitHub Actions build

This fork needs its own long-lived signing key. The original Magisk private key cannot be recovered from `Magisk-v31.1.apk`; the public signing certificate is all that APK contains. This workflow uses a new key and signs the manager and flashable ZIP through Magisk's `config.prop` build settings.

## Before running the workflow

1. The supplied target is [TheRealShadowCoder/Magisk](https://github.com/TheRealShadowCoder/Magisk), currently public. Push this fork, including its submodules and `.github/workflows/build-v32-custom.yml`, only after the Hide-app port is complete. Source and commit history will be visible to everyone.
2. Generate a signing key on your PC and keep a protected offline backup. In PowerShell, run `keytool -genkeypair -v -keystore .\magisk-custom-release.jks -alias magiskcustom -keyalg RSA -keysize 2048 -validity 10000 -storetype JKS`. Enter and record a strong store password and key password at the prompts.
3. Convert the keystore to one-line Base64 with `[Convert]::ToBase64String([IO.File]::ReadAllBytes('.\magisk-custom-release.jks'))`.
4. In GitHub, open **Settings → Secrets and variables → Actions → New repository secret** and add:
   - `MAGISK_KEYSTORE_B64`: the Base64 output from the previous step
   - `MAGISK_KEYSTORE_PASS`: the keystore password
   - `MAGISK_KEY_ALIAS`: `magiskcustom`
   - `MAGISK_KEY_PASS`: the key password
5. Open **Actions → Magisk custom v32 build → Run workflow**. When complete, download the `magisk-v32-custom` artifact.

Do not commit the keystore or passwords. Losing the private key means future builds cannot update-install over an APK signed with this key; users would need to uninstall the old manager first. A custom-signed APK and its paired Magisk core must be used together because the daemon checks the manager signing certificate.

The Hide-app feature port is not part of this workflow file by itself. It must be restored in the application and native core before a build can provide that behavior.
