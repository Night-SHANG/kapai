param(
    [string]$GodotExe = $env:GODOT_EXE,
    [int]$GodotStepTimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotExe)) { throw "Pass -GodotExe or set GODOT_EXE." }
if (-not (Test-Path $GodotExe)) { throw "Godot executable not found: $GodotExe" }

function Invoke-Godot {
    param(
        [string[]]$Arguments,
        [string]$Label,
        [int]$TimeoutSeconds = $GodotStepTimeoutSeconds
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $GodotExe
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add([string]$arg)
    }

    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi

    if (-not $p.Start()) {
        throw "$Label could not start Godot."
    }

    $stdoutTask = $p.StandardOutput.ReadToEndAsync()
    $stderrTask = $p.StandardError.ReadToEndAsync()

    $completed = $p.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
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
        if ($combined.Contains($pattern)) {
            throw "$Label reported fatal pattern: $pattern"
        }
    }

    if ($p.ExitCode -ne 0) {
        throw "$Label failed with exit code $($p.ExitCode)"
    }

    return $combined
}

$versionText = Invoke-Godot -Arguments @("--version") -Label "Godot version" -TimeoutSeconds 15
if ($versionText -notmatch "^4\.7\.1\.stable") {
    throw "P0-2 requires Godot 4.7.1 stable. Got: $versionText"
}

$Gas = Join-Path $Here "gas"
$Light = Join-Path $Here "lightweight"

& (Join-Path $Here "install_dependencies.ps1") -ProjectPath $Gas

Write-Host "[P0-2] Importing GodotGAS project"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Gas,"--import") -Label "GodotGAS import" | Out-Null

Write-Host "[P0-2] Running GodotGAS core semantics"
Invoke-Godot -Arguments @("--headless","--path",$Gas) -Label "GodotGAS core" | Out-Null

Write-Host "[P0-2] Importing lightweight project"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Light,"--import") -Label "Lightweight import" | Out-Null

Write-Host "[P0-2] Running lightweight core semantics"
Invoke-Godot -Arguments @("--headless","--path",$Light,"--script","res://scripts/preflight.gd") -Label "Lightweight core" | Out-Null

Write-Host "[P0-2] CORE SEMANTICS COMPLETE"