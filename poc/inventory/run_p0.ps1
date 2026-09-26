param(
    [string]$GodotExe = $env:GODOT_EXE,
    [int]$GodotStepTimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $Here "..\..")).Path
$ExpectedGlootCommit = "ce88b7adc7b952b4df8ebe4836339de334d0d0cc"

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
if ($version -notmatch "^4\.7\.1\.stable") { throw "P0-4 requires Godot 4.7.1 stable. Got: $version" }

$cacheRoot = Join-Path $RepoRoot ".cache"
$glootClone = Join-Path $cacheRoot "gloot-p0-4-v3.0.2"
$addonsDir = Join-Path $Here "addons"
$glootDest = Join-Path $addonsDir "gloot"
$generatedDir = Join-Path $Here "generated"

New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
if (Test-Path $glootClone) { Remove-Item -Recurse -Force $glootClone }
if (Test-Path $glootDest) { Remove-Item -Recurse -Force $glootDest }
if (Test-Path $generatedDir) { Remove-Item -Recurse -Force $generatedDir }

Write-Host "[P0-4] Installing pinned GLoot v3.0.2"
git clone --quiet --depth 1 --branch v3.0.2 https://github.com/peter-kish/gloot.git $glootClone
if ($LASTEXITCODE -ne 0) { throw "Failed to clone GLoot v3.0.2" }
$actualCommit = (git -C $glootClone rev-parse HEAD).Trim()
if ($actualCommit -ne $ExpectedGlootCommit) {
    throw "GLoot tag drift: expected $ExpectedGlootCommit, got $actualCommit"
}
New-Item -ItemType Directory -Force -Path $addonsDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $glootClone "addons\gloot") $glootDest
Write-Host "[P0-4] GLoot dependency PASS | $actualCommit"

Write-Host "[P0-4] Building YARD -> GLoot generated bridge"
python (Join-Path $Here "scripts\build_gloot_bridge.py") --source (Join-Path $Here "fixtures\yard_item_export.json") --out-dir $generatedDir
if ($LASTEXITCODE -ne 0) { throw "GLoot bridge generation failed" }

Write-Host "[P0-4] Warming Godot import/global class cache"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--import") -Label "P0-4 import warmup" -TimeoutSeconds 30 | Out-Null

Write-Host "[P0-4] Running inventory comparison smoke"
Invoke-Godot -Arguments @("--headless","--path",$Here,"--quit-after","300","--script","res://scripts/p0_inventory_smoke.gd") -Label "P0-4 inventory smoke" -TimeoutSeconds 30 | Out-Null

Write-Host "[P0-4] AUTOMATED COMPARISON COMPLETE"
