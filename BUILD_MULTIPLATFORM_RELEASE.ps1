param(
    [string]$ReleaseTag = "v2.0.1"
)

$ErrorActionPreference = "Stop"

$Repository = "Ross0907/Vivado-WDB-Waveform-Converter"
$Workflow = "build-multiplatform-release.yml"

function Assert-Success {
    param([string]$Message)

    if ($LASTEXITCODE -ne 0) {
        throw $Message
    }
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required."
}

gh auth status
Assert-Success "GitHub CLI authentication is required."

gh release view $ReleaseTag -R $Repository *> $null
Assert-Success "Release '$ReleaseTag' does not exist."

gh workflow view $Workflow -R $Repository *> $null
Assert-Success "Workflow '$Workflow' is not available."

$ExistingRunIds = @()
$ExistingRunsJson = gh run list `
    -R $Repository `
    --workflow $Workflow `
    --limit 30 `
    --json databaseId

if ($LASTEXITCODE -eq 0 -and $ExistingRunsJson) {
    $ExistingRunIds = @(
        ($ExistingRunsJson | ConvertFrom-Json) |
        ForEach-Object { [string]$_.databaseId }
    )
}

Write-Host "Starting multi-platform build for $ReleaseTag ..."

gh workflow run $Workflow `
    -R $Repository `
    --ref main `
    -f "release_tag=$ReleaseTag"

Assert-Success "Failed to start the release build workflow."

$RunId = $null

for ($Attempt = 0; $Attempt -lt 40; $Attempt++) {
    Start-Sleep -Seconds 3

    $RunsJson = gh run list `
        -R $Repository `
        --workflow $Workflow `
        --limit 30 `
        --json databaseId,status,conclusion,createdAt

    if ($LASTEXITCODE -ne 0 -or -not $RunsJson) {
        continue
    }

    $Runs = @($RunsJson | ConvertFrom-Json)

    foreach ($Run in $Runs) {
        $CandidateId = [string]$Run.databaseId
        if ($ExistingRunIds -notcontains $CandidateId) {
            $RunId = $CandidateId
            break
        }
    }

    if ($RunId) {
        break
    }
}

if (-not $RunId) {
    throw "The workflow was started, but its run ID could not be resolved."
}

Write-Host "GitHub Actions run: $RunId"
Write-Host "Waiting for all platform builds to complete..."

gh run watch $RunId -R $Repository --exit-status
Assert-Success "One or more platform builds failed."

$Version = $ReleaseTag.TrimStart("v")
$RequiredAssets = @(
    "VivadoWDBWaveformConverter-v$Version-Windows-x64.exe",
    "VivadoWDBWaveformConverter-v$Version-Windows-x64.exe.sha256",
    "VivadoWDBWaveformConverter-v$Version-Linux-x64",
    "VivadoWDBWaveformConverter-v$Version-Linux-x64.sha256",
    "VivadoWDBWaveformConverter-v$Version-Linux-arm64",
    "VivadoWDBWaveformConverter-v$Version-Linux-arm64.sha256",
    "VivadoWDBWaveformConverter-v$Version-macOS-Intel.dmg",
    "VivadoWDBWaveformConverter-v$Version-macOS-Intel.dmg.sha256",
    "VivadoWDBWaveformConverter-v$Version-macOS-AppleSilicon.dmg",
    "VivadoWDBWaveformConverter-v$Version-macOS-AppleSilicon.dmg.sha256"
)

$ReleaseJson = gh release view $ReleaseTag -R $Repository --json assets
Assert-Success "Failed to read release assets."

$Release = $ReleaseJson | ConvertFrom-Json
$AssetNames = @($Release.assets | ForEach-Object { $_.name })
$MissingAssets = @($RequiredAssets | Where-Object { $AssetNames -notcontains $_ })

if ($MissingAssets.Count -gt 0) {
    Write-Host "Missing release assets:"
    $MissingAssets | ForEach-Object { Write-Host "  $_" }
    throw "Release asset verification failed."
}

Write-Host ""
Write-Host "Multi-platform release build completed successfully."
Write-Host "Release ${ReleaseTag}:"
Write-Host "https://github.com/$Repository/releases/tag/$ReleaseTag"
