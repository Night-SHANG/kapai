$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $Here "..\..")).Path
$CacheRoot = Join-Path $RepoRoot ".cache\p0-events"
$AddonsDir = Join-Path $Here "addons"

New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null
New-Item -ItemType Directory -Force -Path $AddonsDir | Out-Null

function Install-PinnedAddon {
    param(
        [string]$Name,
        [string]$Repository,
        [string]$Tag,
        [string]$Commit,
        [string]$SubPath,
        [string]$DestinationName
    )

    $Temp = Join-Path $CacheRoot $Name
    if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
    $Destination = Join-Path $AddonsDir $DestinationName
    if (Test-Path $Destination) { Remove-Item -Recurse -Force $Destination }

    Write-Host "[P0-5] Fetching $Name $Tag ($Commit)"
    git clone --quiet --depth 1 --branch $Tag $Repository $Temp
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $Name" }

    $Actual = (git -C $Temp rev-parse HEAD).Trim()
    if ($Actual -ne $Commit) { throw "$Name tag drift: expected $Commit, got $Actual" }

    $Source = Join-Path $Temp $SubPath
    if (-not (Test-Path $Source)) { throw "$Name addon path not found: $Source" }
    Copy-Item -Recurse -Force $Source $Destination
    Write-Host "[P0-5] $Name dependency PASS | $Actual"
}

Install-PinnedAddon -Name "yard" -Repository "https://github.com/elliotfontaine/yard-godot.git" -Tag "v1.2.0" -Commit "48a518b4bec03c8b5ad446f57a2b669110a1752b" -SubPath "addons\yard" -DestinationName "yard"
Install-PinnedAddon -Name "dialogue-manager" -Repository "https://github.com/nathanhoad/godot_dialogue_manager.git" -Tag "v4.1.0" -Commit "a719088aea342572f29b5559fd8726896c9519b2" -SubPath "addons\dialogue_manager" -DestinationName "dialogue_manager"
Install-PinnedAddon -Name "gdunit4" -Repository "https://github.com/godot-gdunit-labs/gdUnit4.git" -Tag "v6.2.1" -Commit "08ffc7c65b61b1b2edd545616061a99973c13ce1" -SubPath "addons\gdUnit4" -DestinationName "gdUnit4"
