# Builds a distributable Windows installer from an already-built release bundle.
#
# The Windows counterpart to tool/make_dmg.sh, and plain for the same reason:
# one Inno Setup script and one call to ISCC, so there is as little as possible
# between a green test run and a file someone can double-click.
#
#   flutter build windows --release
#   powershell -ExecutionPolicy Bypass -File tool\make_installer.ps1
#
# Pass -Build to have it run the flutter build first.
#
# Note on signing: this produces an UNSIGNED installer. SmartScreen will warn
# on first run ("Windows protected your PC" → More info → Run anyway) until the
# binary is signed with an OV or EV code-signing certificate. That is a paid
# certificate and a step this script deliberately does not fake.
[CmdletBinding()]
param(
    [switch]$Build,
    [string]$SourceDir = 'build\windows\x64\runner\Release'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if ($Build) {
    Write-Host 'flutter build windows --release'
    & flutter.bat build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }
}

$exe = Join-Path $SourceDir 'sshetu.exe'
if (-not (Test-Path $exe)) {
    throw "no release build at $SourceDir - run: flutter build windows --release"
}

# The version people see comes from pubspec, so the installer's name and the
# app's About screen can never disagree.
$line = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$' | Select-Object -First 1
if (-not $line) { throw 'no version: line in pubspec.yaml' }
$version = $line.Matches[0].Groups[1].Value.Trim().Split('+')[0]

# Inno Setup installs per-user by default, which is not on PATH and not under
# Program Files - both are checked rather than assuming either.
$candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe'
)
$iscc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { $iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source }
if (-not $iscc) {
    throw "Inno Setup not found. Install it with: winget install JRSoftware.InnoSetup"
}

& $iscc "/DMyAppVersion=$version" 'windows\installer\sshetu.iss' | Out-Null
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }

# Says what it made, and what it did not: an unsigned installer is worth
# knowing about before the file is sent to anyone.
$out = "windows\installer\output\SSHetu-Setup-$version.exe"
if (-not (Test-Path $out)) { throw "ISCC reported success but $out is missing" }
Write-Output $out
Write-Warning 'unsigned - SmartScreen will warn on first run'
