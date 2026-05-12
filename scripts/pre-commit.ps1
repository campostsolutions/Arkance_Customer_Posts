# Updates POST VERSION in staged .cps files before commit.
# Usage: copy this into .git/hooks/pre-commit or run manually.

Add-Content -Path "$gitTop\pre-commit.log" -Value "Script started at $(Get-Date)"

$gitTop = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not a Git repository. Initialize a repository or run this from inside one."
    exit 1
}

Push-Location $gitTop
try {
    $commitCount = git rev-list --count HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        $commitCount = 0
    }
    [int]$nextVersion = [int]$commitCount + 1

    Add-Content -Path "$gitTop\pre-commit.log" -Value "nextVersion: $nextVersion"

    $allStagedFiles = git diff --cached --name-only
    Add-Content -Path "$gitTop\pre-commit.log" -Value "stagedFiles: $allStagedFiles"
    if ($allStagedFiles) {
        $nonCpsFiles = $allStagedFiles | Where-Object { $_ -notmatch '\.cps$' }
        if ($nonCpsFiles) {
            Write-Error "Commit rejected: only .cps files may be committed."
            Write-Error "Staged non-.cps files:"
            $nonCpsFiles | ForEach-Object { Write-Error "  $_" }
            exit 1
        }
    }

    $stagedFiles = $allStagedFiles
    if (-not $stagedFiles) {
        exit 0
    }

    $pattern = 'writeComment\("POST VERSION\s*:\s*"\s*\+\s*localize\("[^"]*"\)\s*\);'
    $replacement = "writeComment(`"POST VERSION     : `" + localize(`"$nextVersion`"));"
    $updatedAny = $false

    foreach ($file in $stagedFiles) {
        $fullPath = Join-Path $gitTop $file
        if (-not (Test-Path $fullPath)) {
            continue
        }

        $content = Get-Content -Raw -LiteralPath $fullPath
        $newContent = [regex]::Replace($content, $pattern, $replacement)
        if ($newContent -ne $content) {
            Set-Content -LiteralPath $fullPath -Value $newContent
            git add -- $file
            Write-Host "Updated POST VERSION in $file to $nextVersion"
            $updatedAny = $true
        }
    }

    if ($updatedAny) {
        Write-Host "POST VERSION updated to $nextVersion in staged .cps files."
    }
}
finally {
    Pop-Location
}
