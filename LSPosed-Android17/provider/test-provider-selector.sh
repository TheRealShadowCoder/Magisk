#!/bin/sh
# Offline tests for the Auto preference rule. Does not query or modify Magisk.
set -eu
A17_SOURCE_ONLY=1
. ./a17-provider-control.sh
passed=0
failed=0
check() {
  label="$1"; mode="$2"; magisk="$3"; rezygisk="$4"; wanted="$5"; expected_rc="$6"
  rc=0
  result="$(a17_resolve "$mode" "$magisk" "$rezygisk")" || rc=$?
  if [ "$result" = "$wanted" ] && [ "$rc" -eq "$expected_rc" ]; then
    echo "PASS: $label"
    passed=$((passed+1))
  else
    echo "FAIL: $label ($result, rc=$rc; wanted $wanted rc=$expected_rc)"
    failed=$((failed+1))
  fi
}
check "Auto with both providers chooses built-in Magisk" auto yes yes magisk 0
check "Auto uses Magisk when ReZygisk is missing" auto yes no magisk 0
check "Auto on KernelSU with ReZygisk installed" auto no yes rezygisk 0
check "Auto rejects unavailable injectors" auto no no none 21
check "Manual Magisk choice with both providers present" magisk yes yes magisk 0
check "Manual ReZygisk choice with both present" rezygisk yes yes rezygisk 0
check "Manual ReZygisk choice with no Magisk" rezygisk no yes rezygisk 0
check "Refuse absent Magisk selection" magisk no yes none 22
check "Refuse absent ReZygisk selection" rezygisk yes no none 23
check "Refuse invalid mode" invalid yes yes none 20
echo "$passed selector tests passed, $failed failed"
[ "$failed" -eq 0 ]
