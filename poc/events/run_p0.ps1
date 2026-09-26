param(
    [string]$GodotExe = $env:GODOT_EXE,
    [int]$GodotStepTimeoutSeconds = 60
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
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($stdout) { Write-Host $stdout.TrimEnd() }
        if ($stderr) { Write-Host $stderr.TrimEnd() }
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
if ($version -notmatch "^4\.7\.1\.stable") { throw "P0-5 requires Godot 4.7.1 stable. Got: $version" }

Write-Host "[P0-5] Installing pinned YARD + Dialogue Manager + GdUnit4"
& (Join-Path $Here "install_dependencies.ps1")
if ($LASTEXITCODE -ne 0) { throw "P0-5 dependency install failed" }

Write-Host "[P0-5] Running static Event Preflight"
python (Join-Path $Here "scripts\preflight_events.py") --root $Here
if ($LASTEXITCODE -ne 0) { throw "P0-5 Event Preflight failed" }

$DataDir = Join-Path $Here "data"
if (Test-Path $DataDir) { Remove-Item -Recurse -Force $DataDir }

Write-Host "[P0-5] Initial editor import for plugins/dialogue importer"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Here,"--import") -Label "P0-5 initial import" -TimeoutSeconds 45 | Out-Null

Write-Host "[P0-5] Building YARD EventDefinition resources"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--script","res://scripts/build_resources.gd") -Label "P0-5 resource build" | Out-Null

Write-Host "[P0-5] Re-importing generated EventDefinition resources"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Here,"--import") -Label "P0-5 UID/dialogue import" -TimeoutSeconds 45 | Out-Null

Write-Host "[P0-5] Building YARD event registry"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--script","res://scripts/build_registry.gd") -Label "P0-5 registry build" | Out-Null

Write-Host "[P0-5] Running GdUnit4 domain tests"
Push-Location $Here
try {
    & (Join-Path $Here "addons\gdUnit4\runtest.cmd") --godot_binary $GodotExe -a res://tests/
    if ($LASTEXITCODE -ne 0) { throw "GdUnit4 returned exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

Write-Host "[P0-5] Running full YARD + EventDomain + Dialogue Manager smoke"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--quit-after","600","--script","res://scripts/p0_events_smoke.gd") -Label "P0-5 event smoke" -TimeoutSeconds 45 | Out-Null

Write-Host "[P0-5] AUTOMATED EVENT PIPELINE COMPLETE"
