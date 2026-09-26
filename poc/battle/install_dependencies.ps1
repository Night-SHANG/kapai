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

$license = Join-Path $SourceRoot "LICENSE.md"
if (-not (Test-Path $license)) {
    throw "Card Framework MIT license missing from pinned source."
}
Copy-Item -Path $license -Destination (Join-Path $Destination "_UPSTREAM_LICENSE.md")

$readme = Join-Path $SourceRoot "README.md"
if (-not (Test-Path $readme)) {
    throw "Card Framework README missing from pinned source."
}
$readmeText = Get-Content $readme -Raw
if ($readmeText -notmatch "Godot 4\.6\+") {
    throw "Pinned Card Framework no longer declares Godot 4.6+ compatibility."
}
if ($readmeText -notmatch "version-1\.4\.0") {
    throw "Pinned Card Framework version declaration mismatch."
}

Write-Host "[P0-3:E] Card Framework dependency PASS"
