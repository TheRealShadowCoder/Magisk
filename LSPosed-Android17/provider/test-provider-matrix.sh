#!/bin/sh
set -eu
. "./a17-provider-guard.sh"
pass=0
fail=0
case_test() {
  title="$1"; sdk="$2"; builtin="$3"; standalone="$4"; expected="$5"
  rc=0
  a17_provider_evaluate "$sdk" "$builtin" "$standalone" >/dev/null || rc=$?
  if [ "$rc" -eq "$expected" ]; then
    echo "PASS: $title"
    pass=$((pass+1))
  else
    echo "FAIL: $title got $rc expected $expected"
    fail=$((fail+1))
  fi
}
case_test "API37 Magisk built-in" 37 on "" 0
case_test "API37 Magisk + ReZygisk correctly configured" 37 off rezygisk 0
case_test "API37 KernelSU + ReZygisk" 37 not-magisk rezygisk 0
case_test "API37 external NeoZygisk alone" 37 not-magisk zygisksu 0
case_test "API37 simultaneous built-in and ReZygisk rejected" 37 on rezygisk 12
case_test "API37 two external providers rejected" 37 off rezygisk,zygisksu 11
case_test "API37 Magisk setting unknown rejected" 37 unknown rezygisk 13
case_test "API37 no provider rejected" 37 off "" 14
case_test "API36 rejected" 36 on "" 10
printf '%s\n' "Provider-matrix tests: $pass pass, $fail fail"
[ "$fail" -eq 0 ]
