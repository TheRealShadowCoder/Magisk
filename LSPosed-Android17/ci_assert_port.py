#!/usr/bin/env python3
"""Fail closed when essential Android 17 port anchors go missing.

This checks source integration, NOT runtime correctness. Android 17 device hook
tests are required before any "fully ported" release claim.
"""
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
dest = Path(sys.argv[2])
checks = []

def require(identifier, path, pattern, should_exist=True):
    source = root / path
    text = source.read_text(encoding="utf-8") if source.is_file() else ""
    exists = bool(re.search(pattern, text, re.MULTILINE | re.DOTALL))
    ok = exists == should_exist
    checks.append(dict(id=identifier, file=path, static_source_gate="PASS" if ok else "FAIL"))
    return ok

build = "build.gradle.kts"
view = "manager/src/main/kotlin/org/matrix/vector/manager/ui/screens/modules/ModulesViewModel.kt"
service = "daemon/src/main/kotlin/org/matrix/vector/daemon/ipc/ManagerService.kt"
sys = "daemon/src/main/kotlin/org/matrix/vector/daemon/system/SystemExtensions.kt"
modapp = "daemon/src/main/kotlin/org/matrix/vector/daemon/ipc/ModuleAppService.kt"
cache = "daemon/src/main/kotlin/org/matrix/vector/daemon/data/ConfigCache.kt"

require("API37_COMPILE", build, r"val androidCompileSdkVersion\s*=\s*37")
require("API37_TARGET", build, r"val androidTargetSdkVersion\s*=\s*37")
require("PAGE_SIZE_16K", build, r"max-page-size=16384")
require("BINDER_SESSION_API37", "hiddenapi/stubs/src/main/java/android/app/IServiceConnection.java",
        r"connected\(ComponentName name, IBinder service, IBinderSession session, boolean dead\)")
require("MANAGER_SCAN_SERIALIZATION", view, r"request\s*!=\s*scanGeneration\.get\(\)")
require("MANAGER_FALSE_EMPTY_PREVENTION", view,
        r"if \(result\.daemonAvailable && !result\.scanFailed\)\s*\{\s*_discovered\.value")
require("MANAGER_SCAN_STATE_SNAPSHOT", view, r"private data class ModuleScanResult")
require("DAEMON_FAIL_CLOSED", service, r'packageManager\s*\?:\s*throw IllegalStateException\("PackageManager not initialized"\)')
require("DAEMON_NO_FALSE_EMPTY_FALLBACK", service,
        r"packageManager\?\.getInstalledPackagesFromAllUsers\(flags, filterNoProcess\)\s*\?:\s*emptyList\(",
        should_exist=False)
require("PROCESS_LOOKUP_RETENTION", sys, r'Component lookup failed for')
require("MODULE_GENERATION_EVICTION", cache, r"ModuleAppService\.forgetReplacedModules\(newModules\)")
require("MODULE_GENERATION_PER_PACKAGE", modapp,
        r"serviceMap\s*=\s*ConcurrentHashMap<String, ModuleAppService>\(\)")
require("MODULE_GENERATION_EVICTION_METHOD", modapp, r"fun forgetReplacedModules\(")
# Identifying the native ART source is not the same thing as testing its hooks.
report = {
    "scope": "Android 17 API 37 LSPosed-derived framework",
    "type": "static source assertions",
    "runtime_compatibility_tested": False,
    "all_android17_issues_fixed": False,
    "source_checks": checks,
    "passed": sum(c["static_source_gate"] == "PASS" for c in checks),
    "total": len(checks),
}
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"passed": report["passed"], "total": report["total"]}))
if report["passed"] != report["total"]:
    for c in checks:
        if c["static_source_gate"] != "PASS":
            print("FAILED:", c["id"], c["file"], file=sys.stderr)
    sys.exit(1)
