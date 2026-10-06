# Publishes a new Love Tracking APK to GitHub Releases.
#
# The install QR (docs/install-qr.png) points at
#   https://github.com/Petra-Miracle/Love-Tracking/releases/latest/download/love-tracking.apk
# which GitHub always resolves to the newest release, so the same QR serves every update.
#
# Usage (from the project root):
#   .\scripts\release.ps1 -Notes "Perbaikan login dan tampilan peta"
#
# Requirements: gh CLI logged in, config/prod.json (or config/dev.json) with the production API URL.

param(
    [string]$Notes = "Pembaruan Love Tracking."
)

# Native tools (flutter, git, gh) write progress to stderr; only their exit codes signal failure.
$ErrorActionPreference = 'Continue'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Assert-Success([string]$step) {
    if ($LASTEXITCODE -ne 0) { Write-Error "$step failed (exit $LASTEXITCODE)"; exit 1 }
}

# Next version: 1.0.0+1 -> 1.0.1+2. A higher versionCode lets Android install it as an update.
$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') { Write-Error 'version not found in pubspec.yaml'; exit 1 }
$version = "$($Matches[1]).$($Matches[2]).$([int]$Matches[3] + 1)"
$build = [int]$Matches[4] + 1
Write-Host "Releasing $version (build $build)"

$config = if (Test-Path config/prod.json) { 'config/prod.json' } else { 'config/dev.json' }
flutter build apk --release "--dart-define-from-file=$config" --build-name=$version --build-number=$build
Assert-Success 'flutter build'
Copy-Item build/app/outputs/flutter-apk/app-release.apk build/love-tracking.apk -Force

# Record the version only after a successful build.
$pubspec = $pubspec -replace '(?m)^version:.*$', "version: $version+$build"
[System.IO.File]::WriteAllText((Resolve-Path pubspec.yaml), $pubspec)
git add pubspec.yaml
git commit -m "Release $version"
Assert-Success 'git commit'
git push
Assert-Success 'git push'

$body = @"
$Notes

**Install / update:** scan QR atau buka di HP Android:
https://github.com/Petra-Miracle/Love-Tracking/releases/latest/download/love-tracking.apk
"@
gh release create "v$version" build/love-tracking.apk --target main --title "Love Tracking $version" --latest --notes $body
Assert-Success 'gh release create'
Write-Host "Done. The install QR now serves $version."
