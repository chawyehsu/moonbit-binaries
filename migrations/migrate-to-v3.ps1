#!/usr/bin/env pwsh
#Requires -Version 7

<#
.SYNOPSIS
    Index migration script.
.DESCRIPTION
    Migrate index from v2 to v3.
.PARAMETER Production
    Production mode. Default is development mode.
.LINK
    https://github.com/chawyehsu/moonbit-binaries
#>
param(
    [Parameter(Mandatory = $false)]
    [switch]$Production
)

Set-StrictMode -Version Latest

$DebugPreference = if ($Production) { 'SilentlyContinue' } else { 'Continue' }


# Final output directory
$outputDir = if ($Production) { "$PSScriptRoot/../v3" } else { "$PSScriptRoot/../tmp/v3" }

# ensure the working directory exists
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
} else {
    # clean up existing files
    Get-ChildItem -Path $outputDir | Remove-Item -Recurse -Force
}

# download prod index files
$INDEX_V2_PROD_ZIP = 'https://github.com/chawyehsu/moonbit-binaries/archive/refs/heads/gh-pages.zip'

# Extract v2 files from the zip and copy to output directory
& {
    $tempZipPath = [System.IO.Path]::GetTempFileName()
    Invoke-WebRequest -Uri $INDEX_V2_PROD_ZIP -OutFile $tempZipPath

    $tempExtractPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
    Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath

    $v2ExtractedPath = [System.IO.Path]::Combine($tempExtractPath, 'moonbit-binaries-gh-pages', 'v2')

    Copy-Item -Path (Join-Path $v2ExtractedPath '*') -Destination $outputDir -Recurse -Force

    Remove-Item -Path $tempZipPath -Force
    Remove-Item -Path $tempExtractPath -Recurse -Force
}

# region index.json
& {
    $v2Index = Get-Content -Path (Join-Path $outputDir 'index.json') | ConvertFrom-Json

    $v3Index = [ordered]@{
        version      = 3
        lastModified = $v2Index.lastModified
        channels     = $v2Index.channels
    }

    $v3IndexPath = "$outputDir/index.json"
    $v3IndexJson = $v3Index | ConvertTo-Json -Depth 99
    $v3IndexJson -replace "`r`n", "`n" | Set-Content -Path $v3IndexPath
    Write-Debug "$($v3IndexPath):`n$v3IndexJson"
}
# endregion

# region channel-*.json
$targets = @(
    'aarch64-apple-darwin'
    'x86_64-apple-darwin'
    'x86_64-unknown-linux'
    'x86_64-pc-windows'
)

@('channel-latest.json' , 'channel-nightly.json', 'channel-bleeding.json') | ForEach-Object {
    $v2ChannelIndex = Get-Content -Path (Join-Path $outputDir $_) | ConvertFrom-Json

    $v3ChannelIndex = [ordered]@{
        version      = 3
        lastModified = $v2ChannelIndex.lastModified
        releases     = $v2ChannelIndex.releases | ForEach-Object {
            $_ | Add-Member -MemberType NoteProperty -Name 'targets' -Value $targets -PassThru
        }
    }

    $v3ChannelFilePath = "$outputDir/$_"
    $v3ChannelIndexJson = $v3ChannelIndex | ConvertTo-Json -Depth 99
    $v3ChannelIndexJson -replace "`r`n", "`n" | Set-Content -Path $v3ChannelFilePath
    Write-Debug "$($v3ChannelFilePath):`n$v3ChannelIndexJson"
}
# endregion
