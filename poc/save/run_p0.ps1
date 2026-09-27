param(
    [string]$GodotExe = $env:GODOT_EXE,
    [int]$GodotStepTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotExe)) { throw "Pass -GodotExe or set GODOT_EXE." }
if (-not (Test-Path $GodotExe)) { throw "Godot executable not found: $GodotExe" }

function Invoke-Godot {
    param([string[]]$Arguments,[string]$Label,[int]$TimeoutSeconds=$GodotStepTimeoutSeconds)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $GodotExe
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($arg in $Arguments) { [void]$psi.ArgumentList.Add([string]$arg) }
    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw "$Label could not start Godot." }
    $stdoutTask = $p.StandardOutput.ReadToEndAsync()
    $stderrTask = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
        try { $p.Kill($true) } catch {}
        try { $p.WaitForExit() } catch {}
        throw "$Label exceeded hard timeout of $TimeoutSeconds seconds."
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $combined = ($stdout + [Environment]::NewLine + $stderr).Trim()
    if ($stdout) { Write-Host $stdout.TrimEnd() }
    if ($stderr) { Write-Host $stderr.TrimEnd() }
    foreach ($pattern in @("SCRIPT ERROR:","Parse Error:","Failed to load script","CrashHandlerException:")) {
        if ($combined.Contains($pattern)) { throw "$Label reported fatal pattern: $pattern" }
    }
    if ($p.ExitCode -ne 0) { throw "$Label failed with exit code $($p.ExitCode)" }
    return $combined
}

$version = Invoke-Godot -Arguments @("--version") -Label "Godot version" -TimeoutSeconds 15
if ($version -notmatch "^4\.7\.1\.stable") { throw "P0-6 requires Godot 4.7.1 stable. Got: $version" }

Write-Host "[P0-6] Installing pinned candidates + GdUnit4"
& (Join-Path $Here "install_dependencies.ps1")
if ($LASTEXITCODE -ne 0) { throw "P0-6 dependency install failed" }

Write-Host "[P0-6] Static Save DTO Preflight"
python (Join-Path $Here "common\preflight_save.py")
if ($LASTEXITCODE -ne 0) { throw "P0-6 Save Preflight failed" }

foreach ($ProjectName in @("savestate","enhanced")) {
    $Project = Join-Path $Here $ProjectName
    $GodotCache = Join-Path $Project ".godot"
    $Result = Join-Path $Project "result"
    if (Test-Path $GodotCache) { Remove-Item -Recurse -Force $GodotCache }
    if (Test-Path $Result) { Remove-Item -Recurse -Force $Result }

    Write-Host "[P0-6] $ProjectName editor class scan"
    Invoke-Godot -Arguments @("--headless","--editor","--path",$Project,"--import") -Label "$ProjectName import" -TimeoutSeconds 60 | Out-Null

    Write-Host "[P0-6] $ProjectName GdUnit contract tests"
    Push-Location $Project
    try {
        & (Join-Path $Project "addons\gdUnit4\runtest.cmd") --godot_binary $GodotExe -a res://tests/
        if ($LASTEXITCODE -ne 0) { throw "$ProjectName GdUnit4 returned exit code $LASTEXITCODE" }
    }
    finally { Pop-Location }

    Write-Host "[P0-6] $ProjectName integration / corruption / migration / benchmark"
    $Smoke = "res://scripts/" + ($(if ($ProjectName -eq "savestate") { "savestate_smoke.gd" } else { "enhanced_smoke.gd" }))
    Invoke-Godot -Arguments @("--headless","--path",$Project,"--quit-after","900","--script",$Smoke) -Label "$ProjectName smoke" -TimeoutSeconds 90 | Out-Null
}

Write-Host "[P0-6] Comparing candidates"
python (Join-Path $Here "common\compare_results.py")
if ($LASTEXITCODE -ne 0) { throw "P0-6 comparison found no acceptable winner" }

Write-Host "[P0-6] AUTOMATED SAVE P0 COMPLETE"
