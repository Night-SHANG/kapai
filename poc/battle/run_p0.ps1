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
if ($version -notmatch "^4\.7\.1\.stable") { throw "P0-3 requires Godot 4.7.1 stable. Got: $version" }

Write-Host "[P0-3] Running Phase A draw-model autosim"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--script","res://scripts/phase_a_draw_models.gd") -Label "P0-3 Phase A" | Out-Null

Write-Host "[P0-3] PHASE A COMPLETE"

Write-Host "[P0-3] Running Phase B action-economy autosim"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--script","res://scripts/phase_b_action_models.gd") -Label "P0-3 Phase B" | Out-Null

Write-Host "[P0-3] PHASE B COMPLETE"

Write-Host "[P0-3] Running Phase C formation/sync autosim"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--script","res://scripts/phase_c_formation_sync.gd") -Label "P0-3 Phase C" | Out-Null

Write-Host "[P0-3] PHASE C COMPLETE"

Write-Host "[P0-3] Running Phase D integrated BattleState/BattleCommand smoke"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--script","res://scripts/phase_d_core_smoke.gd") -Label "P0-3 Phase D" | Out-Null

Write-Host "[P0-3] PHASE D COMPLETE"

Write-Host "[P0-3] Installing pinned Card Framework for Phase E"
& (Join-Path $Here "install_dependencies.ps1")

Write-Host "[P0-3] Running Phase E input/presentation smoke"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--script","res://scripts/phase_e_input_presentation_smoke.gd") -Label "P0-3 Phase E" | Out-Null

Write-Host "[P0-3] PHASE A + B + C + D + E COMPLETE"