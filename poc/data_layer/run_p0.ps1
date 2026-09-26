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

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "Could not detect Godot 4.7.1 stable from version output: $VersionText"
}

Write-Host "[P0] Godot: $Version"

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
Invoke-Godot -Arguments @("--headless","--editor","--path",$Yard,"--import") -Label "YARD editor import" | Out-Null

Write-Host "[P0] Building YARD resource files"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Yard,"--script","res://scripts/build_resources.gd") -Label "YARD resource build" | Out-Null

Write-Host "[P0] Re-importing YARD project after resource generation"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Yard,"--import") -Label "YARD UID scan" | Out-Null

Write-Host "[P0] Building YARD registry"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Yard,"--script","res://scripts/build_registry.gd") -Label "YARD registry build" | Out-Null

Write-Host "[P0] Running YARD preflight"
Invoke-Godot -Arguments @("--headless","--path",$Yard,"--script","res://scripts/preflight.gd") -Label "YARD preflight" | Out-Null

Write-Host "[P0] Importing DataTables project"
Invoke-Godot -Arguments @("--headless","--editor","--path",$DataTables,"--import") -Label "DataTables editor import" | Out-Null

Write-Host "[P0] Building DataTables table"
Invoke-Godot -Arguments @("--headless","--path",$DataTables,"--script","res://scripts/build_table.gd") -Label "DataTables build" | Out-Null

Write-Host "[P0] Re-importing DataTables project after table generation"
Invoke-Godot -Arguments @("--headless","--editor","--path",$DataTables,"--import") -Label "DataTables table import" | Out-Null

Write-Host "[P0] Running DataTables preflight"
Invoke-Godot -Arguments @("--headless","--path",$DataTables,"--script","res://scripts/preflight.gd") -Label "DataTables preflight" | Out-Null

Write-Host "[P0] Automated bootstrap completed without fatal Godot script errors."
Write-Host "[P0] This is still not the final data-layer decision."
