$ErrorActionPreference = 'Stop'
$output = Resolve-Path "$PSScriptRoot/../../dist/native-win"
$target = Join-Path $env:TEMP 'DimBlueDot-install-test'
$setup = Join-Path $output 'DimBlueDot-1.1.1-Win10-x64-Setup.exe'
$installed = Start-Process $setup -ArgumentList @('/S', "/D=$target") -Wait -PassThru
if ($installed.ExitCode -ne 0) { throw 'Silent installation failed' }
foreach ($file in @('DimBlueDot.exe', 'Uninstall.exe', '使用说明.txt')) {
  if (!(Test-Path (Join-Path $target $file))) { throw "Missing installed file: $file" }
}
$installedBytes = (Get-ChildItem $target -Recurse -File | Measure-Object Length -Sum).Sum
if ((Get-Item (Join-Path $target 'DimBlueDot.exe')).VersionInfo.CompanyName -ne '戌無营造') { throw 'Incorrect author credit in installed application' }
if ($installedBytes -gt 5MB) { throw "Installed directory too big: $installedBytes" }
Write-Output "Installed directory: $installedBytes bytes"

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class NativeTest {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr w, uint m, IntPtr p, IntPtr l);
  public static IntPtr FindTimer() { return FindWindow("DimBlueDotNative", null); }
}
'@
$stdout = Join-Path $env:TEMP 'DimBlueDot-startup.txt'
$stderr = Join-Path $env:TEMP 'DimBlueDot-startup-errors.txt'
$process = Start-Process (Join-Path $target 'DimBlueDot.exe') -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try {
  $until = [DateTime]::UtcNow.AddSeconds(10)
  $window = [IntPtr]::Zero
  while ([DateTime]::UtcNow -lt $until -and $window -eq [IntPtr]::Zero) {
    Start-Sleep -Milliseconds 100
    $window = [NativeTest]::FindTimer()
  }
  if ($window -eq [IntPtr]::Zero) {
    $process.Refresh()
    Write-Output "Launch diagnostics: HasExited=$($process.HasExited), ExitCode=$($process.ExitCode), Path=$target"
    Get-Content $stdout, $stderr -ErrorAction SilentlyContinue | Write-Output
    Get-ChildItem $target | Select-Object Name, Length | ConvertTo-Json -Compress | Write-Output
    Get-Process DimBlueDot -ErrorAction SilentlyContinue | Select-Object Id, SessionId, MainWindowHandle, MainWindowTitle, Responding | ConvertTo-Json -Compress | Write-Output
    Get-Process -Id $PID | Select-Object Id, SessionId | ConvertTo-Json -Compress | Write-Output
    throw 'Installed application did not launch'
  }
  [void][NativeTest]::SendMessage($window, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 200
  $process.Refresh()
  if ($process.HasExited) { throw 'Close exited rather than hid to tray' }
  [void][NativeTest]::SendMessage($window, 0x111, [IntPtr]303, [IntPtr]::Zero)
  if (!$process.WaitForExit(5000)) { throw 'Explicit Quit did not exit' }
} finally {
  $process.Refresh()
  if (!$process.HasExited) { Stop-Process -Id $process.Id }
}
$uninstalled = Start-Process (Join-Path $target 'Uninstall.exe') -ArgumentList "/S _?=$target" -Wait -PassThru
if ($uninstalled.ExitCode -ne 0 -or (Test-Path (Join-Path $target 'DimBlueDot.exe'))) {
  Write-Output "Uninstall diagnostics: ExitCode=$($uninstalled.ExitCode), Target=$target"
  Get-ChildItem $target | Select-Object Name, Length | ConvertTo-Json -Compress | Write-Output
  throw 'Uninstall failed'
}
if (Test-Path $target) { Remove-Item $target -Recurse -Force }
$reportPath = Join-Path $output 'build-report.json'
$report = Get-Content $reportPath -Raw | ConvertFrom-Json
$report | Add-Member -NotePropertyName installedBytes -NotePropertyValue $installedBytes
$report | Add-Member -NotePropertyName validationOS -NotePropertyValue ([Environment]::OSVersion.VersionString)
$report | Add-Member -NotePropertyName validation -NotePropertyValue 'Native logic, Win32 window messages, installation, installed launch, close-to-tray, quit, uninstall: PASS'
$report | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding utf8
Write-Output 'PASS: install, launch installed app, close-to-tray, quit, and uninstall'
