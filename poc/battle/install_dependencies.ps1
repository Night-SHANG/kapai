param()

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$Commit = "a74b713863adb27a22965a8e6ed039d0c4016791"
$Archive = Join-Path $env:TEMP "card-framework-$Commit.zip"
$Extract = Join-Path $env:TEMP "card-framework-$Commit"
$SourceRoot = Join-Path $Extract "card-framework-$Commit"
$SourceAddon = Join-Path $SourceRoot "addons\card-framework"
$Destination = Join-Path $Here "addons\card-framework"

if (Test-Path $Destination) {
    Remove-Item $Destination -Recurse -Force
}
if (Test-Path $Extract) {
    Remove-Item $Extract -Recurse -Force
}
if (Test-Path $Archive) {
    Remove-Item $Archive -Force
}

$url = "https://github.com/chun92/card-framework/archive/$Commit.zip"
Write-Host "[P0-3:E] Downloading Card Framework v1.4.0 @ $Commit"
Invoke-WebRequest -Uri $url -OutFile $Archive
Expand-Archive -Path $Archive -DestinationPath $Extract

if (-not (Test-Path $SourceAddon)) {
    throw "Card Framework addon missing after extraction: $SourceAddon"
}

New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
Copy-Item -Path $SourceAddon -Destination $Destination -Recurse

$licenseDestination = Join-Path $Destination "_UPSTREAM_LICENSE.md"
$licenseUrl = "https://raw.githubusercontent.com/chun92/card-framework/$Commit/LICENSE.md"
Invoke-WebRequest -Uri $licenseUrl -OutFile $licenseDestination
$licenseText = Get-Content $licenseDestination -Raw
if ($licenseText -notmatch "MIT License") {
    throw "Pinned Card Framework license verification failed."
}

$readmeUrl = "https://raw.githubusercontent.com/chun92/card-framework/$Commit/README.md"
$readmePath = Join-Path $env:TEMP "card-framework-$Commit-README.md"
Invoke-WebRequest -Uri $readmeUrl -OutFile $readmePath
$readmeText = Get-Content $readmePath -Raw
if ($readmeText -notmatch "Godot 4\.6\+") {
    throw "Pinned Card Framework no longer declares Godot 4.6+ compatibility."
}
if ($readmeText -notmatch "version-1\.4\.0") {
    throw "Pinned Card Framework version declaration mismatch."
}

Write-Host "[P0-3:E] Card Framework dependency PASS"