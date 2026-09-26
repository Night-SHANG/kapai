param([string]$GodotExe = $env:GODOT_EXE)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotExe)) { throw "Pass -GodotExe or set GODOT_EXE." }
if (-not (Test-Path $GodotExe)) { throw "Godot executable not found: $GodotExe" }

function Invoke-Godot {
    param([string[]]$Arguments,[string]$Label)

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $GodotExe -ArgumentList $Arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $stdout = if (Test-Path $stdoutFile) { Get-Content -Raw $stdoutFile } else { "" }
        $stderr = if (Test-Path $stderrFile) { Get-Content -Raw $stderrFile } else { "" }
        $combined = ($stdout + [Environment]::NewLine + $stderr).Trim()

        if ($stdout) { Write-Host $stdout.TrimEnd() }
        if ($stderr) { Write-Host $stderr.TrimEnd() }

        foreach ($pattern in @("SCRIPT ERROR:","Parse Error:","Failed to load script","CrashHandlerException:")) {
            if ($combined.Contains($pattern)) { throw "$Label reported fatal pattern: $pattern" }
        }
        if ($p.ExitCode -ne 0) { throw "$Label failed with exit code $($p.ExitCode)" }
        return $combined
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $stdoutFile,$stderrFile
    }
}

$versionText = Invoke-Godot -Arguments @("--version") -Label "Godot version"
if ($versionText -notmatch "^4\.7\.1\.stable") { throw "P0-2 requires Godot 4.7.1 stable. Got: $versionText" }

$Gas = Join-Path $Here "gas"
$Light = Join-Path $Here "lightweight"

& (Join-Path $Here "install_dependencies.ps1") -ProjectPath $Gas

Write-Host "[P0-2] Importing GodotGAS project"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Gas,"--import") -Label "GodotGAS import" | Out-Null

Write-Host "[P0-2] Running GodotGAS core semantics"
Invoke-Godot -Arguments @("--headless","--path",$Gas,"--script","res://scripts/preflight.gd") -Label "GodotGAS core" | Out-Null

Write-Host "[P0-2] Importing lightweight project"
Invoke-Godot -Arguments @("--headless","--editor","--path",$Light,"--import") -Label "Lightweight import" | Out-Null

Write-Host "[P0-2] Running lightweight core semantics"
Invoke-Godot -Arguments @("--headless","--path",$Light,"--script","res://scripts/preflight.gd") -Label "Lightweight core" | Out-Null

Write-Host "[P0-2] CORE SEMANTICS COMPLETE"
