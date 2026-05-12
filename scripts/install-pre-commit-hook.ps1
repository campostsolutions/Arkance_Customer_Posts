# Installs the pre-commit hook from scripts/pre-commit.ps1 into the current Git repository.

$gitTop = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not a Git repository. Initialize a repository or run this from inside one."
    exit 1
}

$hookSource = Join-Path $gitTop 'scripts\pre-commit.ps1'
$hookTarget = Join-Path $gitTop '.git\hooks\pre-commit'
$hookTargetCmd = Join-Path $gitTop '.git\hooks\pre-commit.cmd'
if (-not (Test-Path $hookSource)) {
    Write-Error "Hook source file not found: $hookSource"
    exit 1
}

$hookContent = @"
#!/usr/bin/env pwsh

# Git pre-commit hook for updating POST VERSION in staged .cps files.
# This script delegates to scripts/pre-commit.ps1.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$hookSource"
"@

$hookCmdContent = @"
@echo off
setlocal
set "HOOK_DIR=%~dp0"
set "SCRIPT_PATH=%HOOK_DIR%..\..\scripts\pre-commit.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
endlocal
exit /b %ERRORLEVEL%
"@

Set-Content -LiteralPath $hookTarget -Value $hookContent -Encoding UTF8
Set-Content -LiteralPath $hookTargetCmd -Value $hookCmdContent -Encoding ASCII
# Make the hook executable if running under Git Bash or WSL
if (Test-Path '/usr/bin/chmod') {
    & /usr/bin/chmod +x "$hookTarget" "$hookTargetCmd" 2>$null
}

Write-Host "Installed Git pre-commit hook at: $hookTarget"
Write-Host "Installed Windows wrapper pre-commit hook at: $hookTargetCmd"
