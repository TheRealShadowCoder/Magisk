param(
  [ValidateSet('help','coverage','status','health','modules','module-info','module-schema',
    'module-settings','module-enable','module-disable','apps','app','logs','denylist-list',
    'denylist-add','denylist-remove','journal','audit','report')]
  [string]$Action='report',
  [string]$Package='',
  [string]$ModuleId='',
  [string]$Process='',
  [switch]$ExportZip
)
$ErrorActionPreference='Stop'
$root='/data/adb/modules/fxga_adbdiag/fxga_diag.sh'
$modOps=@('module-info','module-schema','module-settings','module-enable','module-disable')
if ($modOps -contains $Action) {
    if ($ModuleId -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$') { throw 'Invalid -ModuleId' }
    $argList=@($ModuleId)
} elseif (@('app','logs','denylist-remove') -contains $Action) {
    if ($Package -notmatch '^[A-Za-z0-9_.]+$') { throw 'Invalid -Package' }
    $argList=@($Package)
} elseif ($Action -eq 'denylist-add') {
    if ($Package -notmatch '^[A-Za-z0-9_.]+$' -or $Process -notmatch '^[A-Za-z0-9_.:]+$') {
        throw 'Invalid -Package or -Process'
    }
    $argList=@($Package,$Process)
} elseif ($Action -eq 'report' -and $Package) {
    if ($Package -notmatch '^[A-Za-z0-9_.]+$') { throw 'Invalid -Package' }
    $argList=@($Package)
} else {
    $argList=@()
}
$adb=Get-Command adb -ErrorAction Stop
$commandLine='sh ' + $root + ' ' + (($Action + $argList) -join ' ')
$output=& $adb.Source shell su -c $commandLine 2>&1
$exitCode=$LASTEXITCODE
$text=($output | Out-String)
if ($exitCode -ne 0) { throw ('ADB command failed (' + $exitCode + '): ' + $text) }
Write-Output $text
if ($ExportZip -or $Action -eq 'report') {
    $folder=Join-Path $env:USERPROFILE 'Desktop\A52 Report'
    New-Item -Path $folder -ItemType Directory -Force | Out-Null
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $zipPath=Join-Path $folder ('FXGA-' + $Action + '-' + $stamp + '.zip')
    $tmp=Join-Path $env:TEMP ('fxga-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -Path $tmp -ItemType Directory -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $tmp 'diagnostics.txt'),$text)
        Compress-Archive -Path (Join-Path $tmp 'diagnostics.txt') -DestinationPath $zipPath
        Write-Output ('Report: ' + $zipPath)
    } finally {
        Remove-Item -LiteralPath $tmp -Force -Recurse -ErrorAction SilentlyContinue
    }
}
