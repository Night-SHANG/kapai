param([string]$GodotExe = $env:GODOT_EXE)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotExe)) { throw "Pass -GodotExe or set GODOT_EXE." }
if (-not (Test-Path $GodotExe)) { throw "Godot executable not found: $GodotExe" }

$Version = (& $GodotExe --version).Trim()
Write-Host "[P0] Godot: $Version"
if (-not $Version.StartsWith("4.7.1.stable")) { throw "Wrong Godot version. Required 4.7.1 stable, got: $Version" }

$Python = $null
if (Get-Command py -ErrorAction SilentlyContinue) { $Python = "py" }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $Python = "python" }
else { throw "Python 3 not found (py/python)." }

Write-Host "[P0] Generating deterministic fixture"
& $Python (Join-Path $Here "generate_fixture.py")
if ($LASTEXITCODE -ne 0) { throw "Fixture generation failed" }

foreach ($Variant in @("yard","datatables")) {
    & (Join-Path $Here "install_dependencies.ps1") -Variant $Variant
    if ($LASTEXITCODE -ne 0) { throw "Dependency install failed for $Variant" }
}

$Yard = Join-Path $Here "yard"
$DataTables = Join-Path $Here "datatables"

Write-Host "[P0] Importing YARD project"
& $GodotExe --headless --editor --path $Yard --quit-after 2
if ($LASTEXITCODE -ne 0) { throw "YARD editor import failed" }

Write-Host "[P0] Building YARD resource files"
& $GodotExe --headless --editor --path $Yard --script "res://scripts/build_resources.gd"
if ($LASTEXITCODE -ne 0) { throw "YARD resource build failed" }

& $GodotExe --headless --editor --path $Yard --quit-after 2
if ($LASTEXITCODE -ne 0) { throw "YARD UID scan failed" }

Write-Host "[P0] Building YARD registry"
& $GodotExe --headless --editor --path $Yard --script "res://scripts/build_registry.gd"
if ($LASTEXITCODE -ne 0) { throw "YARD registry build failed" }

Write-Host "[P0] Running YARD preflight"
& $GodotExe --headless --path $Yard --script "res://scripts/preflight.gd"
if ($LASTEXITCODE -ne 0) { throw "YARD preflight failed" }

Write-Host "[P0] Importing DataTables project"
& $GodotExe --headless --editor --path $DataTables --quit-after 2
if ($LASTEXITCODE -ne 0) { throw "DataTables editor import failed" }

Write-Host "[P0] Building DataTables table"
& $GodotExe --headless --path $DataTables --script "res://scripts/build_table.gd"
if ($LASTEXITCODE -ne 0) { throw "DataTables build failed" }

Write-Host "[P0] Running DataTables preflight"
& $GodotExe --headless --path $DataTables --script "res://scripts/preflight.gd"
if ($LASTEXITCODE -ne 0) { throw "DataTables preflight failed" }

Write-Host "[P0] Automated bootstrap completed. This is not yet a final data-layer decision."
