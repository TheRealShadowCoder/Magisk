# FXGA signing identity (public pin)

This folder intentionally contains **no private keys or signing secrets**.

Pinned SHA-256 digest of the public X.509 certificate used by the verified FXGA v32 release APK:

```text
f4d7d3bddca7f03c7be193febd4afeaf53a5d4960ca9b70d32527c2d2b3cbf6d
```

The CI guard checks the release keystore's certificate before compiling and the APK's verified signing certificate before publishing. The digest must not be replaced during normal patches or updates. See [CUSTOM_BUILD.md](../CUSTOM_BUILD.md).
