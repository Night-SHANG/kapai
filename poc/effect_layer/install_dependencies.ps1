param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $Here "..\..")
$CacheRoot = Join-Path $RepoRoot ".cache\p0-effect-layer"
$Temp = Join-Path $CacheRoot "godot-gas"

New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectPath "addons") | Out-Null

if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }

$Repo = "https://github.com/yulrun/godot-gas.git"
$Tag = "v1.1.0"
$Commit = "42ae230840bfbe4d62629e6f5d1d5ba1a65a4a3b"

Write-Host "[P0-2] Fetching GodotGAS $Tag ($Commit)"
git clone --quiet --depth 1 --branch $Tag $Repo $Temp
if ($LASTEXITCODE -ne 0) { throw "git clone failed for GodotGAS" }

$Actual = (git -C $Temp rev-parse HEAD).Trim()
if ($Actual -ne $Commit) {
    throw "GodotGAS commit mismatch. Expected $Commit, got $Actual"
}

$Source = Join-Path $Temp "GodotGAS"
$Dest = Join-Path (Join-Path $ProjectPath "addons") "GodotGAS"
if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
Copy-Item -Recurse -Force $Source $Dest

Write-Host "[P0-2] GodotGAS installed."
