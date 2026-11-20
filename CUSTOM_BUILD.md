# FXGA Magisk release signing — locked identity

Every future FXGA Magisk patch, Android 17 fix, feature and version upgrade **must use the same custom private signing key** used for the first successfully compiled FXGA v32 release.

## Public certificate fingerprint

```text
f4d7d3bddca7f03c7be193febd4afeaf53a5d4960ca9b70d32527c2d2b3cbf6d
```

This SHA-256 fingerprint was extracted from the X.509 certificate embedded in `FXGA_Magisk_v32_Android17_Release.apk`. The fingerprint is public. It is **not** the private key, the password, the APK checksum, or the certificate of official Magisk by John Wu.

## Release requirements

1. Always use the existing GitHub Actions secret `MAGISK_KEYSTORE_B64` to restore the original custom release keystore, with its existing alias and passwords.
2. Never generate a fresh signing key to fix builds, change a version, or adjust a feature. The private key cannot be recovered from a public certificate or APK.
3. Never commit or upload private signing material, keystore passwords or the keystore itself. Maintain a secure encrypted offline backup.
4. Stop the release workflow if any signing secret is missing or the key's public certificate differs from the pinned SHA-256 fingerprint. Do **not** fall back to debug signing.
5. Use Android `apksigner` to verify the finished APK, including v2/v3 signature, and reject it if the embedded certificate changes.
6. Do not change the app's package ID or Magisk's manager/core signing relationship without an explicit migration plan; a matching certificate alone does not guarantee an installable update.
7. If the pinned identity check fails, restore the original keystore or investigate the change. Do **not** edit the fingerprint to match an unrecognized new key.

## Current secret names

Retain these exact existing values in **GitHub → Settings → Secrets and variables → Actions**:

- `MAGISK_KEYSTORE_B64` — Base64-encoded existing custom signing keystore.
- `MAGISK_KEYSTORE_PASS` — original keystore password.
- `MAGISK_KEY_ALIAS` — original key alias.
- `MAGISK_KEY_PASS` — original private-key password.

The release workflow restores and checks the keystore, compiles Magisk, removes temporary signing material, verifies `out/app-release.apk` against the pinned public certificate, and only then publishes a build artifact.

The enforcement script is `scripts/fxga/verify-release-signer.sh`. The pinned public digest is `signing/FXGA_RELEASE_CERT_SHA256.txt`.

## Original Magisk APK limitation

Official topjohnwu Magisk APKs use a different publisher signing identity. This policy preserves **FXGA custom-key continuity only**; it cannot reuse or recover the official signing private key. Future FXGA releases should use the same FXGA keystore and preserve Magisk's paired app/core signing expectations.
