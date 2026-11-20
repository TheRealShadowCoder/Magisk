#!/usr/bin/env python3
"""Static regression checks for FXGA Magisk v32 / Vector Android 17 interoperability.

Static checks are NOT evidence of a working Zygote hook or a boot-safe flash.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
boot = (root / "native/src/core/bootstages.rs").read_text()
zyg = (root / "native/src/core/zygisk/module.cpp").read_text()
api = (root / "native/src/core/zygisk/api.hpp").read_text()
build = (root / ".github/workflows/build-v32-custom.yml").read_text()

def need(label: str, passed: bool) -> None:
    print(("PASS" if passed else "FAIL") + ": " + label)
    if not passed:
        raise SystemExit(1)

need("Fork Zygisk supports API version 5", bool(re.search(r"ZYGISK_API_VERSION\s+5", api)))
need("Loader continues to accept Vector API v4", "case 4:" in zyg)
need("Safe Mode exists and executes before normal provider policy",
     boot.index("if safe_mode {") < boot.index("let use_rezygisk = fxga_wants_rezygisk();"))
need("ReZygisk only enabled with explicit choice", 's.trim() == "rezygisk"' in boot)
need("ReZygisk enabled-module evidence required", 
     all(a in boot for a in ("module.prop", '"disable"', '"remove"')))
need("Built-in remains default", "let builtin_enabled = !use_rezygisk;" in boot)
need("Daemon Zygisk activation follows provider choice",
     "self.zygisk_enabled.store(builtin_enabled, Ordering::Release)" in boot)
need("Magisk database settings follow provider choice",
     "self.set_db_setting(DbEntryKey::ZygiskConfig, i32::from(builtin_enabled))" in boot)
need("Current-boot handshaking prevents false provider claims",
     '"magisk-provider-aware-boot-id"' in boot and '"/proc/sys/kernel/random/boot_id"' in boot)
need("Build workflow includes test target",
     "tools/fxga/test_vector_provider_compat.py" in build)
print("STATIC SUCCESS only: actual Android 17/Vector runtime tests still required")
