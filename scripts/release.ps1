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

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

# Bump version: 1.0.0+1 -> 1.0.1+2. A higher versionCode lets Android install it as an update.
$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') { throw 'version not found in pubspec.yaml' }
$version = "$($Matches[1]).$($Matches[2]).$([int]$Matches[3] + 1)"
$build = [int]$Matches[4] + 1
$pubspec = $pubspec -replace '(?m)^version:.*$', "version: $version+$build"
[System.IO.File]::WriteAllText((Resolve-Path pubspec.yaml), $pubspec)
Write-Host "Releasing $version (build $build)"

$config = if (Test-Path config/prod.json) { 'config/prod.json' } else { 'config/dev.json' }
flutter build apk --release "--dart-define-from-file=$config"
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
Copy-Item build/app/outputs/flutter-apk/app-release.apk build/love-tracking.apk -Force

git add pubspec.yaml
git commit -m "Release $version" | Out-Null
git push
if ($LASTEXITCODE -ne 0) { throw 'git push failed' }

$body = @"
$Notes

**Install / update:** scan QR atau buka di HP Android:
https://github.com/Petra-Miracle/Love-Tracking/releases/latest/download/love-tracking.apk
"@
gh release create "v$version" build/love-tracking.apk --target main --title "Love Tracking $version" --latest --notes $body
if ($LASTEXITCODE -ne 0) { throw 'gh release create failed' }
Write-Host "Done. The install QR now serves $version."
