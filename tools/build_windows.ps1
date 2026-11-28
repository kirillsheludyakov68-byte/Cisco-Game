param(
    [string]$GodotExe = $env:GODOT_BIN,
    [string]$Output = "build/windows/CiscoGame.exe"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot

if (-not $GodotExe) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) {
        $GodotExe = $command.Source
    }
}

if (-not $GodotExe -or -not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found. Set GODOT_BIN or pass -GodotExe."
}

$OutputPath = Join-Path $Root $Output
$OutputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue

Push-Location $Root
try {
    $arguments = @(
        "--headless",
        "--path",
        ".",
        "--export-release",
        '"Windows Desktop"',
        $Output
    )
    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WorkingDirectory $Root -NoNewWindow -Wait -PassThru
    if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) {
        throw "Godot export failed with exit code $($process.ExitCode)."
    }
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw "Godot did not create $OutputPath."
    }
    Get-Item -LiteralPath $OutputPath | Select-Object FullName, Length, LastWriteTime
} finally {
    Pop-Location
}
