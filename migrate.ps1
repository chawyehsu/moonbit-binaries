#!/usr/bin/env pwsh
#Requires -Version 7

<#
.SYNOPSIS
    Index migration script.
.DESCRIPTION
    Migrate index from v1 to v2.
.PARAMETER Production
    Production mode. Default is development mode.
.LINK
    https://github.com/chawyehsu/moonbit-binaries
#>
param(
    [Parameter(Mandatory = $false)]
    [switch]$Production
)

$DebugPreference = if ($Production) { 'SilentlyContinue' } else { 'Continue' }

$INDEX_V1_URL = 'https://raw.githubusercontent.com/chawyehsu/moonbit-binaries/gh-pages/index.json'

$workingDir = if ($Production) { "$PSScriptRoot/v2" } else { "$PSScriptRoot/tmp/v2" }

# ensure the working directory exists
if (-not (Test-Path $workingDir)) {
    New-Item -ItemType Directory -Path $workingDir | Out-Null
}

# download the index file
$indexV1 = Invoke-RestMethod $INDEX_V1_URL

# region channel-latest.json
$channelLatestReleases = $indexV1.core.releases
# reverse the releases array
[array]::Reverse($channelLatestReleases)

$channelLatestReleases = $channelLatestReleases | ForEach-Object {
    [ordered]@{
        version = $_.version
    }
}

$channelLatest = [ordered]@{
    version      = 2
    lastModified = $indexV1.core.last_modified
    releases     = $channelLatestReleases
}

$v2JsonChannelLatestPath = "$workingDir/channel-latest.json"
$v2JsonChannelLatest = $channelLatest | ConvertTo-Json -Depth 99
$v2JsonChannelLatest | Set-Content -Path $v2JsonChannelLatestPath
Write-Debug "$($v2JsonChannelLatestPath):`n$v2JsonChannelLatest"
# endregion

# region index.json
$indexV2 = [ordered]@{
    version      = 2
    lastModified = $indexV1.core.last_modified
    channels     = @(
        [ordered]@{
            name    = 'latest'
            version = $channelLatest.releases[-1].version
        }
    )
    targets      = @(
        'aarch64-apple-darwin'
        'x86_64-apple-darwin'
        'x86_64-unknown-linux'
        'x86_64-pc-windows'
    )
}

$v2JsonIndexPath = "$workingDir/index.json"
$v2JsonIndex = $indexV2 | ConvertTo-Json -Depth 99
$v2JsonIndex | Set-Content -Path $v2JsonIndexPath
Write-Debug "$($v2JsonIndexPath):`n$v2JsonIndex"
# endregion

# region components jsons
$channelLatestReleases | ForEach-Object {
    $version = $_.version
    $targets = $indexV2.targets

    $targets | ForEach-Object {
        $target = $_
        $v2JsonComponentPath = "$workingDir/latest/$version/$target.json"
        $parentDir = Split-Path -Path $v2JsonComponentPath -Parent

        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir | Out-Null
        }

        $fileToolchain = switch ($target) {
            'aarch64-apple-darwin' { "moonbit-v$version-darwin-arm64.tar.gz" }
            'x86_64-apple-darwin' { "moonbit-v$version-darwin-x64.tar.gz" }
            'x86_64-unknown-linux' { "moonbit-v$version-linux-x64.tar.gz" }
            'x86_64-pc-windows' { "moonbit-v$version-win-x64.zip" }
        }
        $fileLibcore = "moonbit-core-v$version.zip"

        $sha256Toolchain = switch ($target) {
            'aarch64-apple-darwin' { $indexV1.'darwin-arm64'.releases | Where-Object { $_.version -eq $version } | Select-Object -ExpandProperty sha256 }
            'x86_64-apple-darwin' { $indexV1.'darwin-x64'.releases | Where-Object { $_.version -eq $version } | Select-Object -ExpandProperty sha256 }
            'x86_64-unknown-linux' { $indexV1.'linux-x64'.releases | Where-Object { $_.version -eq $version } | Select-Object -ExpandProperty sha256 }
            'x86_64-pc-windows' { $indexV1.'win-x64'.releases | Where-Object { $_.version -eq $version } | Select-Object -ExpandProperty sha256 }
        }
        $sha256Libcore = $indexV1.core.releases | Where-Object { $_.version -eq $version } | Select-Object -ExpandProperty sha256

        $components = [ordered]@{
            version    = 2
            components = @(
                [ordered]@{
                    name   = 'toolchain'
                    file   = $fileToolchain
                    sha256 = $sha256Toolchain
                }
                [ordered]@{
                    name   = 'libcore'
                    file   = $fileLibcore
                    sha256 = $sha256Libcore
                }
            )
        }

        $v2JsonComponents = $components | ConvertTo-Json -Depth 99
        $v2JsonComponents | Set-Content -Path $v2JsonComponentPath
        Write-Debug "$($v2JsonComponentPath):`n$v2JsonComponents"
    }
}
# endregion
