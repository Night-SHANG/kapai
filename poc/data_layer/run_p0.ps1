param([string]$GodotExe = $env:GODOT_EXE)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotExe)) { throw "Pass -GodotExe or set GODOT_EXE." }
if (-not (Test-Path $GodotExe)) { throw "Godot executable not found: $GodotExe" }

function Invoke-Godot {
    param(
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$Label
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $startParams = @{
            FilePath = $GodotExe
            ArgumentList = $Arguments
            Wait = $true
            PassThru = $true
            NoNewWindow = $true
            RedirectStandardOutput = $stdoutFile
            RedirectStandardError = $stderrFile
        }
        $process = Start-Process @startParams

        $stdout = if (Test-Path $stdoutFile) { Get-Content -Raw $stdoutFile } else { "" }
        $stderr = if (Test-Path $stderrFile) { Get-Content -Raw $stderrFile } else { "" }
        $combined = ($stdout + [Environment]::NewLine + $stderr).Trim()

        if (-not [string]::IsNullOrWhiteSpace($stdout)) { Write-Host $stdout.TrimEnd() }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) { Write-Host $stderr.TrimEnd() }

        $fatalPatterns = @("SCRIPT ERROR:", "Parse Error:", "Failed to load script")
        foreach ($pattern in $fatalPatterns) {
            if ($combined.Contains($pattern)) {
                throw "$Label reported fatal Godot error pattern: $pattern"
            }
        }

        if ($process.ExitCode -ne 0) {
            throw "$Label failed with Godot exit code $($process.ExitCode)."
        }

        return $combined
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $stdoutFile,$stderrFile
    }
}

$VersionText = Invoke-Godot -Arguments @("--version") -Label "Godot version check"
$Version = ($VersionText -split "\r?\n" | Where-Object { $_ -match "^4\.7\.1\.stable" } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($Version)) { throw "Could not detect Godot 4.7.1 stable from version output: $VersionText" }
Write-Host "[P0] Godot: $Version"

$Python = $null
if (Get-Command py -ErrorAction SilentlyContinue) { $Python = "py" }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $Python = "python" }
else { throw "Python 3 not found (py/python)." }

$RuntimeOut = Join-Path $Here "result\runtime"
New-Item -ItemType Directory -Force -Path $RuntimeOut | Out-Null

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
Invoke-Godot -Arguments @("--headless","--editor","--path",$Yard,"--import") -Label "YARD editor import" | Out-Null

Write-Host "[P0] Building YARD resource files"
Invoke-Godot -Arguments @("--headless","--path",$Yard,"--script","res://scripts/build_resources.gd") -Label "YARD resource build" | Out-Null

Write-Host "[P0] Re-importing YARD project after resource generation"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Yard,"--import") -Label "YARD UID scan" | Out-Null

Write-Host "[P0] Building YARD registry without editor-only YARD internals"
Invoke-Godot -Arguments @("--headless","--path",$Yard,"--script","res://scripts/build_registry.gd") -Label "YARD registry build" | Out-Null

Write-Host "[P0] Running YARD preflight"
Invoke-Godot -Arguments @("--headless","--path",$Yard,"--script","res://scripts/preflight.gd") -Label "YARD preflight" | Out-Null

Write-Host "[P0] Exporting YARD migration manifest"
Invoke-Godot -Arguments @("--headless","--path",$Yard,"--script","res://scripts/export_manifest.gd") -Label "YARD migration export" | Out-Null
Copy-Item -Force (Join-Path $Yard "result\yard_export.json") (Join-Path $RuntimeOut "yard_export.json")

Write-Host "[P0] Importing DataTables project"
Invoke-Godot -Arguments @("--headless","--editor","--path",$DataTables,"--import") -Label "DataTables editor import" | Out-Null

Write-Host "[P0] Building DataTables table"
Invoke-Godot -Arguments @("--headless","--path",$DataTables,"--script","res://scripts/build_table.gd") -Label "DataTables build" | Out-Null

Write-Host "[P0] Re-importing DataTables project after table generation"
Invoke-Godot -Arguments @("--headless","--editor","--path",$DataTables,"--import") -Label "DataTables table import" | Out-Null

Write-Host "[P0] Running DataTables preflight"
Invoke-Godot -Arguments @("--headless","--path",$DataTables,"--script","res://scripts/preflight.gd") -Label "DataTables preflight" | Out-Null

Write-Host "[P0] Running DataTables JSON/CSV round-trip"
Invoke-Godot -Arguments @("--headless","--path",$DataTables,"--script","res://scripts/io_roundtrip.gd") -Label "DataTables IO round-trip" | Out-Null
Copy-Item -Force (Join-Path $DataTables "result\datatables_export.json") (Join-Path $RuntimeOut "datatables_export.json")
Copy-Item -Force (Join-Path $DataTables "result\datatables_export.csv") (Join-Path $RuntimeOut "datatables_export.csv")

Write-Host "[P0] Running format/diff/merge analysis"
& $Python (Join-Path $Here "analyze_formats.py")
if ($LASTEXITCODE -ne 0) { throw "Format analysis failed" }

Write-Host "[P0] Testing additive schema evolution on old serialized data"
$SchemaRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kapai-p0-schema-" + [guid]::NewGuid().ToString("N"))
$YardSchema = Join-Path $SchemaRoot "yard"
$DataTablesSchema = Join-Path $SchemaRoot "datatables"
New-Item -ItemType Directory -Force -Path $SchemaRoot | Out-Null

try {
    Copy-Item -Recurse -Force $Yard $YardSchema
    Copy-Item -Recurse -Force $DataTables $DataTablesSchema

    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $YardSchema ".godot")
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $DataTablesSchema ".godot")

    $YardSchemaFile = Join-Path $YardSchema "scripts\card_definition.gd"
    $yardSchemaText = Get-Content -Raw $YardSchemaFile
    $yardReplacement = "@export var base_value: int = 0" + [Environment]::NewLine + "@export var schema_probe: int = 7"
    $yardSchemaText = $yardSchemaText.Replace("@export var base_value: int = 0", $yardReplacement)
    Set-Content -Path $YardSchemaFile -Value $yardSchemaText -Encoding utf8 -NoNewline

    $DataTablesSchemaFile = Join-Path $DataTablesSchema "scripts\card_row.gd"
    $dtSchemaText = Get-Content -Raw $DataTablesSchemaFile
    $dtReplacement = "@export var base_value: int = 0" + [Environment]::NewLine + "@export var schema_probe: int = 7"
    $dtSchemaText = $dtSchemaText.Replace("@export var base_value: int = 0", $dtReplacement)
    Set-Content -Path $DataTablesSchemaFile -Value $dtSchemaText -Encoding utf8 -NoNewline

    Invoke-Godot -Arguments @("--headless","--editor","--path",$YardSchema,"--import") -Label "YARD schema import" | Out-Null
    Invoke-Godot -Arguments @("--headless","--path",$YardSchema,"--script","res://scripts/schema_probe.gd") -Label "YARD schema probe" | Out-Null

    Invoke-Godot -Arguments @("--headless","--editor","--path",$DataTablesSchema,"--import") -Label "DataTables schema import" | Out-Null
    Invoke-Godot -Arguments @("--headless","--path",$DataTablesSchema,"--script","res://scripts/schema_probe.gd") -Label "DataTables schema probe" | Out-Null
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $SchemaRoot
}

Write-Host "[P0] Testing YARD stable ID after physical resource move"
$OriginalCard = Join-Path $Yard "data\cards\card_bastion_000.tres"
$MovedDir = Join-Path $Yard "data\cards\moved"
$MovedCard = Join-Path $MovedDir "card_bastion_000.tres"
New-Item -ItemType Directory -Force -Path $MovedDir | Out-Null

try {
    Move-Item -Force $OriginalCard $MovedCard
    Invoke-Godot -Arguments @("--headless","--editor","--path",$Yard,"--import") -Label "YARD moved resource import" | Out-Null
    Invoke-Godot -Arguments @("--headless","--path",$Yard,"--script","res://scripts/preflight_move.gd") -Label "YARD stable ID move probe" | Out-Null
}
finally {
    if (Test-Path $MovedCard) {
        Move-Item -Force $MovedCard $OriginalCard
    }
}

Write-Host "[P0] Automated P0-1 CI experiments completed."
Write-Host "[P0] Local Editor UX and real Codex editing remain separate checks before final lock."
