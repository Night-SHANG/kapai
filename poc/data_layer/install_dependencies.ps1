param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("yard", "datatables")]
    [string]$Variant
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$Project = Join-Path $Here $Variant
$RepoRoot = Resolve-Path (Join-Path $Here "..\..")
$CacheRoot = Join-Path $RepoRoot ".cache\p0-data-layer"

New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Project "addons") | Out-Null

function Install-PinnedAddon {
    param([string]$Name,[string]$Repository,[string]$Tag,[string]$Commit,[string]$SubPath)
    $Temp = Join-Path $CacheRoot $Name
    if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
    Write-Host "[P0] Fetching $Name $Tag ($Commit)"
    git clone --quiet --depth 1 --branch $Tag $Repository $Temp
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $Name" }
    $Actual = (git -C $Temp rev-parse HEAD).Trim()
    if ($Actual -ne $Commit) { throw "$Name commit mismatch. Expected $Commit, got $Actual" }
    $Source = Join-Path $Temp $SubPath
    if (-not (Test-Path $Source)) { throw "$Name addon path not found: $Source" }
    $DestinationName = Split-Path $SubPath -Leaf
    $Destination = Join-Path (Join-Path $Project "addons") $DestinationName
    if (Test-Path $Destination) { Remove-Item -Recurse -Force $Destination }
    Copy-Item -Recurse -Force $Source $Destination
}

Install-PinnedAddon -Name "gdunit4" -Repository "https://github.com/godot-gdunit-labs/gdUnit4.git" -Tag "v6.2.1" -Commit "08ffc7c65b61b1b2edd545616061a99973c13ce1" -SubPath "addons/gdUnit4"

if ($Variant -eq "yard") {
    Install-PinnedAddon -Name "yard" -Repository "https://github.com/elliotfontaine/yard-godot.git" -Tag "v1.2.0" -Commit "48a518b4bec03c8b5ad446f57a2b669110a1752b" -SubPath "addons/yard"
} else {
    Install-PinnedAddon -Name "datatables" -Repository "https://github.com/yulrun/godot-data-tables-addon.git" -Tag "v1.0.1" -Commit "f405b187b013e3914b812db201f014ac946335a3" -SubPath "addons/GodotDataTables"
}

Write-Host "[P0] Dependencies installed for $Variant"
