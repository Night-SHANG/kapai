param([Parameter(Mandatory=$true)][string]$ProjectPath,[Parameter(Mandatory=$true)][string]$ScriptPath,[string]$GodotExe=$env:GODOT_EXE,[switch]$Editor)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($GodotExe)) { throw "Pass -GodotExe or set GODOT_EXE." }
if (-not (Test-Path $GodotExe)) { throw "Godot executable not found: $GodotExe" }
$args = @("--headless")
if ($Editor) { $args += "--editor" }
$args += @("--path",$ProjectPath,"--script",$ScriptPath)
& $GodotExe @args
exit $LASTEXITCODE
