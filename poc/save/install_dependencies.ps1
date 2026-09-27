$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $Here "..\..")).Path
$CacheRoot = Join-Path $RepoRoot ".cache\p0-save"

New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null

function Checkout-Commit {
    param([string]$Name,[string]$Repository,[string]$Commit)
    $Temp = Join-Path $CacheRoot $Name
    if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
    New-Item -ItemType Directory -Force -Path $Temp | Out-Null
    git -C $Temp init --quiet
    git -C $Temp remote add origin $Repository
    git -C $Temp fetch --quiet --depth 1 origin $Commit
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed for $Name" }
    git -C $Temp checkout --quiet --detach FETCH_HEAD
    $Actual = (git -C $Temp rev-parse HEAD).Trim()
    if ($Actual -ne $Commit) { throw "$Name commit drift: expected $Commit got $Actual" }
    Write-Host "[P0-6] $Name dependency PASS | $Actual"
    return $Temp
}

function Copy-Addon {
    param([string]$SourceRoot,[string]$SubPath,[string]$Destination)
    if (Test-Path $Destination) { Remove-Item -Recurse -Force $Destination }
    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Copy-Item -Recurse -Force (Join-Path $SourceRoot $SubPath) $Destination
}

$SaveState = Checkout-Commit -Name "savestate" -Repository "https://github.com/youssof20/savestate.git" -Commit "22b912aebbc6b52b3b31f74d3d83fec48b53870c"
$Enhanced = Checkout-Commit -Name "enhanced" -Repository "https://github.com/Amiyadesi/enhance_save_system.git" -Commit "dc92d0bead1c449f36462f22e823b603e356e49a"
$GdUnit = Checkout-Commit -Name "gdunit4" -Repository "https://github.com/godot-gdunit-labs/gdUnit4.git" -Commit "08ffc7c65b61b1b2edd545616061a99973c13ce1"

Copy-Addon $SaveState "addons\savestate" (Join-Path $Here "savestate\addons\savestate")
Copy-Addon $Enhanced "addons\enhance_save_system" (Join-Path $Here "enhanced\addons\enhance_save_system")
Copy-Addon $GdUnit "addons\gdUnit4" (Join-Path $Here "savestate\addons\gdUnit4")
Copy-Addon $GdUnit "addons\gdUnit4" (Join-Path $Here "enhanced\addons\gdUnit4")

foreach ($Project in @("savestate","enhanced")) {
    $FixtureDest = Join-Path $Here "$Project\fixtures"
    if (Test-Path $FixtureDest) { Remove-Item -Recurse -Force $FixtureDest }
    Copy-Item -Recurse -Force (Join-Path $Here "fixtures") $FixtureDest
}
