#!/usr/bin/env pwsh
#Requires -Version 7

<#
.SYNOPSIS
    Moonbit snap script.
.DESCRIPTION
    Snap moonbit core and binaries.
.PARAMETER Production
    Production mode. Default is development mode.
.PARAMETER SnapToolchain
    Snap moonbit toolchain. Default is to snap moonbit core.
.LINK
    https://github.com/chawyehsu/moonbit-binaries
#>
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('latest', 'nightly')]
    [string]$Channel = 'latest',
    [Parameter(Mandatory = $false)]
    [switch]$Merge,
    [Parameter(Mandatory = $false)]
    [switch]$Production = $(if ($env:CI) { $true } else { $false }),
    [Parameter(Mandatory = $false)]
    [Switch]$SnapToolchain,
    [Parameter(Mandatory = $false)]
    [Switch]$Force
)

Set-StrictMode -Version Latest

$DebugPreference = if ((-not $Production) -or $env:CI) { 'Continue' } else { 'SilentlyContinue' }
$ErrorActionPreference = 'Stop'

$INDEX_V2_URL = if (-not $Production) {
    'http://localhost:8080/index.json'
} else {
    'https://raw.githubusercontent.com/chawyehsu/moonbit-binaries/gh-pages/v2/index.json'
}
$CHANNEL_INDEX_URL = if (-not $Production) {
    "http://localhost:8080/channel-$Channel.json"
} else {
    "https://raw.githubusercontent.com/chawyehsu/moonbit-binaries/gh-pages/v2/channel-$Channel.json"
}

$DOWNLOAD_DIR = "$PSScriptRoot/tmp/download"
$GHA_ARTIFACTS_DIR = "$PSScriptRoot/tmp/gha-artifacts"
$DIST_DIR = "$PSScriptRoot/tmp/dist/v2"

$INDEX_FILE = "$DIST_DIR/index.json"
$CHANNEL_INDEX_FILE = "$DIST_DIR/channel-$Channel.json"

function Clear-WorkingDir {
    if ($Production) {
        Remove-Item $DOWNLOAD_DIR -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item $GHA_ARTIFACTS_DIR -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item $DIST_DIR -Force -Recurse -ErrorAction SilentlyContinue
    }
}

function Get-DeployedIndex {
    Write-Debug 'Getting the latest deployed index ...'
    if (Test-Path $DIST_DIR) {
        Remove-Item -Path $DIST_DIR -Recurse -Force
    }
    New-Item -ItemType Directory -Path $DIST_DIR -Force | Out-Null
    Invoke-RestMethod $INDEX_V2_URL -OutFile $INDEX_FILE
    Invoke-RestMethod $CHANNEL_INDEX_URL -OutFile $CHANNEL_INDEX_FILE
}

function Invoke-SnapLibcore {
    $LIBCORE_URL = "https://cli.moonbitlang.com/cores/core-$Channel.zip"
    [OrderedHashtable]$index = Get-Content -Path $INDEX_FILE | ConvertFrom-Json -AsHashtable

    Write-Debug 'Checking last modified date of moonbit libcore ...'
    $libcoreRemoteLastUpdated = Get-Date "$((Invoke-WebRequest -Method HEAD $LIBCORE_URL).Headers.'Last-Modified')" -Format FileDateTimeUniversal
    $indexLastUpdate = [DateTime]::ParseExact($index.lastModified, "yyyyMMdd'T'HHmmssffff'Z'", $null)

    if ($libcoreRemoteLastUpdated -lt $indexLastUpdate) {
        Write-Host "INFO: libcore is up to date. (channel: $Channel)"
        return
    }

    Write-Debug 'Downloading moonbit libcore pkg ...'
    New-Item -Path $DOWNLOAD_DIR -ItemType Directory -Force | Out-Null
    Push-Location $DOWNLOAD_DIR

    $filename = "moonbit-core-$Channel.zip"
    if ($Force -or (-not (Test-Path $filename))) {
        Invoke-WebRequest -Uri $LIBCORE_URL -OutFile $filename
    }

    Write-Debug 'Getting moonbit libcore version number ...'
    Remove-Item -Path "$DOWNLOAD_DIR/core-$Channel" -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $filename -DestinationPath "$DOWNLOAD_DIR/core-$Channel" -Force
    $libcoreActualVersion = (Get-Content -Path "$DOWNLOAD_DIR/core-$Channel/core/moon.mod.json" | ConvertFrom-Json).version
    $libcorePkgSha256 = (Get-FileHash -Path $filename -Algorithm SHA256).Hash.ToLower()

    Write-Host "INFO: Found moonbit libcore version: $libcoreActualVersion"
    $componentLibcore = [ordered]@{
        version = $libcoreActualVersion
        name    = 'libcore'
        file    = "moonbit-core-v$libcoreActualVersion.zip"
        sha256  = $libcorePkgSha256
    }

    Write-Debug 'Saving libcore component json file ...'
    New-Item -Path $GHA_ARTIFACTS_DIR -ItemType Directory -Force | Out-Null
    $componentLibcore | ConvertTo-Json -Depth 99 | Set-Content -Path "$GHA_ARTIFACTS_DIR/component-moonbit-core.json"

    Write-Debug 'Saving moonbit libcore pkg ...'
    Copy-Item -Path $filename -Destination "$GHA_ARTIFACTS_DIR/$($componentLibcore.file)" -Force
    "$libcorePkgSha256  *$($componentLibcore.file)" | Out-File -FilePath "$GHA_ARTIFACTS_DIR/$($componentLibcore.file).sha256" -Encoding ascii -Force
    Pop-Location
}

function Invoke-SnapToolchain {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('aarch64-apple-darwin', 'x86_64-apple-darwin', 'x86_64-unknown-linux', 'x86_64-pc-windows')]
        [string]$Arch
    )

    $TOOLCHAIN_URL = switch ($Arch) {
        'aarch64-apple-darwin' { "https://cli.moonbitlang.com/binaries/$Channel/moonbit-darwin-aarch64.tar.gz" }
        'x86_64-apple-darwin' { "https://cli.moonbitlang.com/binaries/$Channel/moonbit-darwin-x86_64.tar.gz" }
        'x86_64-unknown-linux' { "https://cli.moonbitlang.com/binaries/$Channel/moonbit-linux-x86_64.tar.gz" }
        'x86_64-pc-windows' { "https://cli.moonbitlang.com/binaries/$Channel/moonbit-windows-x86_64.zip" }
    }
    [OrderedHashtable]$index = Get-Content -Path $INDEX_FILE | ConvertFrom-Json -AsHashtable

    Write-Debug 'Checking last modified date of moonbit toolchain ...'
    $toolchainRemoteLastUpdated = Get-Date "$((Invoke-WebRequest -Method HEAD $TOOLCHAIN_URL).Headers.'Last-Modified')" -Format FileDateTimeUniversal
    $indexLastUpdate = [DateTime]::ParseExact($index.lastModified, "yyyyMMdd'T'HHmmssffff'Z'", $null)

    if ($toolchainRemoteLastUpdated -lt $indexLastUpdate) {
        Write-Host "INFO: moonbit toolchain is up to date. (arch: $Arch, channel: $Channel)"
        return
    }

    Write-Debug 'Downloading moonbit toolchain pkg ...'
    New-Item -Path $DOWNLOAD_DIR -ItemType Directory -Force | Out-Null
    Push-Location $DOWNLOAD_DIR

    $filename = switch ($Arch) {
        'aarch64-apple-darwin' { "moonbit-$Channel-darwin-arm64.tar.gz" }
        'x86_64-apple-darwin' { "moonbit-$Channel-darwin-x64.tar.gz" }
        'x86_64-unknown-linux' { "moonbit-$Channel-linux-x64.tar.gz" }
        'x86_64-pc-windows' { "moonbit-$Channel-win-x64.zip" }
    }
    if ($Force -or (-not (Test-Path $filename))) {
        Invoke-WebRequest -Uri $TOOLCHAIN_URL -OutFile $filename
    }

    Write-Debug 'Getting moonbit toolchain version number ...'
    Remove-Item -Path "$DOWNLOAD_DIR/moonbit-$Channel" -Recurse -Force -ErrorAction SilentlyContinue
    if ($Arch -match 'windows') {
        Expand-Archive -Path $filename -DestinationPath "$DOWNLOAD_DIR/moonbit-$Channel" -Force
    } else {
        mkdir -p "$DOWNLOAD_DIR/moonbit-$Channel"
        tar -xf $filename -C "$DOWNLOAD_DIR/moonbit-$Channel"
        chmod +x "$DOWNLOAD_DIR/moonbit-$Channel/bin/moonc"
    }

    Push-Location "$DOWNLOAD_DIR/moonbit-$Channel/bin"
    $VersionString = (& ./moonc -v)
    Pop-Location

    if ($VersionString -match 'v([\d.]+)(?:\+([a-f0-9]+))') {
        $toolchainActualVersion = "$($Matches[1])+$($Matches[2])"
        $toolchainPkgSha256 = (Get-FileHash -Path $filename -Algorithm SHA256).Hash.ToLower()

        Write-Host "INFO: Found moonbit toolchain version: $toolchainActualVersion"
        $componentToolchain = [ordered]@{
            version  = $toolchainActualVersion
            name     = 'toolchain'
            file     = switch ($Arch) {
                'aarch64-apple-darwin' { "moonbit-v$toolchainActualVersion-aarch64-apple-darwin.tar.gz" }
                'x86_64-apple-darwin' { "moonbit-v$toolchainActualVersion-x86_64-apple-darwin.tar.gz" }
                'x86_64-unknown-linux' { "moonbit-v$toolchainActualVersion-x86_64-unknown-linux.tar.gz" }
                'x86_64-pc-windows' { "moonbit-v$toolchainActualVersion-x86_64-pc-windows.zip" }
            }
            'sha256' = $toolchainPkgSha256
        }

        Write-Debug 'Saving toolchain component json file ...'
        New-Item -Path $GHA_ARTIFACTS_DIR -ItemType Directory -Force | Out-Null
        $componentToolchain | ConvertTo-Json -Depth 99 | Set-Content -Path "$GHA_ARTIFACTS_DIR/component-moonbit-toolchain-$Arch.json"

        Write-Debug 'Saving moonbit toolchain pkg ...'
        Copy-Item -Path $filename -Destination "$GHA_ARTIFACTS_DIR/$($componentToolchain.file)" -Force
        "$toolchainPkgSha256  *$($componentToolchain.file)" | Out-File -FilePath "$GHA_ARTIFACTS_DIR/$($componentToolchain.file).sha256" -Encoding ascii -Force
        Pop-Location
    } else {
        Write-Error "Unexpected moonbit toolchain version number found: $VersionString"
        exit 1
    }
}

function Invoke-MergeIndex {
    $componentCoreJsonFile = "$GHA_ARTIFACTS_DIR/component-moonbit-core.json"
    if (-not (Test-Path $componentCoreJsonFile)) {
        Write-Error 'Missing component-moonbit-core.json'
        exit 1
    }

    [OrderedHashtable]$componentCoreJson = Get-Content -Path $componentCoreJsonFile | ConvertFrom-Json -AsHashtable

    @(
        'aarch64-apple-darwin'
        'x86_64-apple-darwin'
        'x86_64-unknown-linux'
        'x86_64-pc-windows'
    ) | ForEach-Object {
        $componentToolchainJsonFile = "$GHA_ARTIFACTS_DIR/component-moonbit-toolchain-$_.json"
        if (-not (Test-Path $componentToolchainJsonFile)) {
            Write-Error "Missing component-moonbit-toolchain-$_.json"
            exit 1
        }

        [OrderedHashtable]$componentToolchainJson = Get-Content -Path $componentToolchainJsonFile | ConvertFrom-Json -AsHashtable

        $componentToolchainVersion = $componentToolchainJson.version
        $componentCoreVersion = $componentCoreJson.version

        if ($componentToolchainVersion -ne $componentCoreVersion) {
            Write-Error "Version mismatch between core ($componentCoreVersion) and toolchain ($componentToolchainVersion, arch: $_)"
            exit 1
        }

        $componentIndex = [ordered]@{
            version    = 2
            components = @(
                $componentToolchainJson | Select-Object -Property name, file, sha256,
                $componentCoreJson | Select-Object -Property name, file, sha256
            )
        }

        $componentIndexFilename = "$componentToolchainVersion/$_.json"
        Write-Host "INFO: Saving component index '$componentIndexFilename' ..."
        $componentIndexPath = "$DIST_DIR/$Channel/$componentToolchainVersion/$componentIndexFilename"
        $componentIndex | ConvertTo-Json -Depth 99 | Set-Content -Path $componentIndexPath
    }

    $dateUpdated = (Get-Date).ToUniversalTime().ToString("yyyyMMdd'T'HHmmssffff'Z'")
    # Update channel index
    [OrderedHashtable]$channelIndex = Get-Content -Path $CHANNEL_INDEX_FILE | ConvertFrom-Json -AsHashtable
    $channelIndexNewRelease = [ordered]@{
        version = $componentCoreJson.version
    }

    $channelIndex.lastModified = $dateUpdated
    $channelIndex.releases = @($channelIndex.releases; $channelIndexNewRelease)
    Write-Host 'INFO: Saving channel index ...'
    $channelIndex | ConvertTo-Json -Depth 99 | Set-Content -Path $CHANNEL_INDEX_FILE

    # Update main index
    [OrderedHashtable]$index = Get-Content -Path $INDEX_FILE | ConvertFrom-Json -AsHashtable
    $index.lastModified = $dateUpdated
    $index.channels | ForEach-Object {
        if ($_.name -eq $Channel) {
            $_.version = $channelIndexNewRelease.version
        }
    }
    Write-Host 'INFO: Saving main index ...'
    $index | ConvertTo-Json -Depth 99 | Set-Content -Path $INDEX_FILE
}

Clear-WorkingDir
Write-Host "INFO: Channel set to: $Channel"

Get-DeployedIndex

if ($Merge) {
    Invoke-MergeIndex
} elseif ($SnapToolchain) {
    if ($IsWindows) {
        Invoke-SnapToolchain -Arch 'x86_64-pc-windows'
    }

    if ($IsLinux) {
        Invoke-SnapToolchain -Arch 'x86_64-unknown-linux'
    }

    if ($IsMacOS) {
        $arch = (uname -sm)
        if ($arch -match 'arm64') {
            Invoke-SnapToolchain -Arch 'aarch64-apple-darwin'
        } else {
            Invoke-SnapToolchain -Arch 'x86_64-apple-darwin'
        }
    }
} else {
    Invoke-SnapLibcore
}
