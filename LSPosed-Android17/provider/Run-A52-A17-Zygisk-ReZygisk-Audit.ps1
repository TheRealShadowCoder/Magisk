# Android 17 A52 — read-only provider diagnostics
# All reports are packed in ONE ZIP at C:\Users\skbus\Desktop\A52 Report
# Nothing is flashed, no root settings are changed and no Zygote is restarted.
param(
    [string]$Destination = "C:\Users\skbus\Desktop\A52 Report"
)
$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$work = Join-Path $env:TEMP ("A52-Zygisk-A17-" + [guid]::NewGuid().ToString("N"))
$zip = Join-Path $Destination ("A52-A17-Zygisk-ReZygisk-$stamp.zip")
New-Item -Path $work -ItemType Directory -Force | Out-Null

function Capture-Adb {
    param([string]$Name, [string[]]$Args)
    $output = ""
    try {
        $output = (& adb @Args 2>&1 | Out-String)
    } catch {
        $output = "Command failed: $($_.Exception.Message)"
    }
    Set-Content -Path (Join-Path $work $Name) -Value $output -Encoding UTF8
}
try {
    Set-Content -Path (Join-Path $work "README.txt") -Encoding UTF8 -Value @'
ANDROID 17 API 37 PROVIDER AUDIT — READ-ONLY
This ZIP contains device and installed-module metadata and limited diagnostic logs.
It is NOT a proof of real Zygisk/Vector hook execution.
Check Zygisk provider mode:
 A) Magisk built-in enabled; ReZygisk, NeoZygisk and ZygiskNext disabled
 B) ReZygisk enabled; Magisk built-in disabled; any other external provider disabled
Upstream ReZygisk zygote_next issue: https://github.com/PerformanC/ReZygisk/issues/374
Before sending logs to others, review them for personal and sensitive information.
No script in this audit reboots, toggles or installs anything.
'@
    Capture-Adb "adb_devices.txt" @("devices","-l")
    Capture-Adb "android_release.txt" @("shell","getprop","ro.build.version.release")
    Capture-Adb "android_sdk.txt" @("shell","getprop","ro.build.version.sdk")
    Capture-Adb "lineage_version.txt" @("shell","getprop","ro.lineage.version")
    Capture-Adb "device.txt" @("shell","getprop","ro.product.device")
    Capture-Adb "root_id.txt" @("shell","su","-c","id")
    Capture-Adb "magisk_version.txt" @("shell","su","-c","magisk -v")
    Capture-Adb "magisk_builtin_zygisk_setting.txt" @("shell","su","-c", 'magisk --sqlite "SELECT value FROM settings WHERE key=''zygisk'';"')
    Capture-Adb "providers_and_module_states.txt" @("shell","su","-c", 'for d in /data/adb/modules/rezygisk /data/adb/modules/zygisksu /data/adb/modules/zygisk_next /data/adb/modules/neozygisk /data/adb/modules/zygisk_vector /data/adb/modules/zygisk_lsposed; do if [ -f "$d/module.prop" ]; then echo "-- $d --"; grep -E "^(id|name|version|versionCode|description)=" "$d/module.prop"; if [ -f "$d/disable" ]; then echo "STATUS=DISABLED"; elif [ -f "$d/remove" ]; then echo "STATUS=REMOVING"; else echo "STATUS=ENABLED"; fi; fi; done')
    Capture-Adb "vector_cli_status.txt" @("shell","su","-c","/data/adb/modules/zygisk_vector/cli status")
    Capture-Adb "zygote_pids.txt" @("shell","su","-c","pidof zygote64 zygote zygote_next system_server vectord")
    Capture-Adb "zygote_next_service.txt" @("shell","getprop","init.svc.zygote_next")
    Capture-Adb "zygote64_service.txt" @("shell","getprop","init.svc.zygote")
    Capture-Adb "zygote_secondary_service.txt" @("shell","getprop","init.svc.zygote_secondary")
    Capture-Adb "user_profiles.txt" @("shell","pm","list","users")
    Capture-Adb "framework_log_directory.txt" @("shell","su","-c","ls -lah /data/adb/lspd/log /data/adb/lsp/log 2>&1")
    Capture-Adb "android17_errors.txt" @("shell","logcat","-d","-v","threadtime","-t","1800","-s","VectorDaemon:*","VectorNative:*","VectorModuleAppService:*","zygisk-core64:*","zygisk-core32:*","zygiskd:*","ReZygisk:*")
    $sdk = ""
    try { $sdk = ((& adb shell getprop ro.build.version.sdk) | Out-String).Trim() } catch {}
    if ($sdk -eq "37") { $status = "PASS: Android 17 (API 37)" }
    elseif (-not $sdk) { $status = "UNKNOWN: Android SDK unavailable. Check ADB connection." }
    else { $status = "FAIL: Expected Android 17 (API 37); found API $sdk" }
    Set-Content (Join-Path $work "API37_CHECK.txt") -Value $status -Encoding UTF8
    New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -CompressionLevel Optimal -Force
    Write-Output $status
    Write-Output "Saved single ZIP: $zip"
    Write-Output "No device settings were changed."
} finally {
    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
}
