#!/usr/bin/env bash
# Public-certificate identity guard for FXGA Magisk releases.
# No secret material is written into this script or its output.
set -euo pipefail
cd "$(dirname "$0")/../.."
pin_file="signing/FXGA_RELEASE_CERT_SHA256.txt"
[[ -f "$pin_file" ]] || { echo "ERROR: release certificate pin missing" >&2; exit 1; }
expected="$(tr -d '[:space:]' < "$pin_file" | tr '[:upper:]' '[:lower:]')"
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: invalid certificate pin" >&2; exit 1; }

check_cert() {
  local actual="$1"
  actual="$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')"
  [[ "$actual" =~ ^[0-9a-f]{64}$ ]] || {
    echo "ERROR: expected a certificate SHA-256 digest" >&2; exit 1;
  }
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: release signing certificate changed. This build is blocked." >&2
    echo "Expected public certificate: $expected" >&2
    echo "Observed public certificate: $actual" >&2
    exit 1
  fi
}

[[ "$#" -ge 1 ]] || { echo "Usage: $0 keystore|apk <path>" >&2; exit 2; }
case "$1" in
  keystore)
    [[ -f signing.jks ]] || { echo "ERROR: signing.jks missing" >&2; exit 1; }
    : "$STORE_PASS"
    : "$KEY_ALIAS"
    # keytool emits the X.509 certificate DER, not the private key.
    digest="$(keytool -exportcert -keystore signing.jks -alias "$KEY_ALIAS" \
       -storepass:env STORE_PASS | sha256sum | awk '{print $1}')"
    check_cert "$digest"
    echo "FXGA pinned keystore certificate verified."
    ;;
  apk)
    [[ "$#" -eq 2 && -f "$2" ]] || { echo "ERROR: missing APK path" >&2; exit 1; }
    apk="$2"
    : "$ANDROID_HOME"
    signer="$(find "$ANDROID_HOME/build-tools" -mindepth 2 -maxdepth 2 \
       -type f -name apksigner -print | sort -V | tail -n 1)"
    [[ -n "$signer" && -x "$signer" ]] || {
      echo "ERROR: Android apksigner unavailable; refusing unchecked upload" >&2; exit 1;
    }
    report="$(mktemp)"
    trap 'rm -f "$report"' EXIT
    "$signer" verify --verbose --print-certs "$apk" > "$report"
    grep -Eq '^Verified using v(2|3) scheme.*: true$' "$report" || {
      echo "ERROR: no verified APK v2/v3 signature" >&2; exit 1;
    }
    count="$(grep -c 'certificate SHA-256 digest:' "$report" || true)"
    [[ "$count" -eq 1 ]] || {
      echo "ERROR: expected exactly one APK signing identity" >&2; exit 1;
    }
    digest="$(sed -nE 's/^Signer #1 certificate SHA-256 digest: ([[:xdigit:]]{64})$/\1/p' "$report" | head -n 1)"
    check_cert "$digest"
    echo "FXGA signed APK certificate verified. This APK may be published."
    ;;
  *) echo "Usage: $0 keystore|apk <path>" >&2; exit 2 ;;
esac
