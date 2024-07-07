#!/usr/bin/env pwsh
#Requires -Version 7

<#
.SYNOPSIS
    Moonbit snap script.
.DESCRIPTION
    Snap moonbit core and binaries.
.PARAMETER Merge
    Merge partial index files.
.PARAMETER SnapToolchain
    Snap moonbit toolchain. Default is to snap moonbit core.
.PARAMETER Force
    Force to snap moonbit core and binaries.
.LINK
    https://github.com/chawyehsu/moonbit-binaries
#>
param(
    [Parameter(Mandatory = $false)]
    [Switch]$Merge,
    [Parameter(Mandatory = $false)]
    [Switch]$SnapToolchain,
    [Parameter(Mandatory = $false)]
    [Switch]$Force
)

Set-StrictMode -Version Latest

$DebugPreference = "Continue"
$ErrorActionPreference = "Stop"

$DistDir = "$PSScriptRoot/dist"
$IndexFile = "$DistDir/index.json"

function Invoke-CheckoutDeployment {
    Write-Debug "Getting latest moonbit-binaries index ..."
    if (Test-Path $DistDir) {
        Remove-Item -Path $DistDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
    Push-Location $DistDir
    Invoke-RestMethod 'https://raw.githubusercontent.com/chawyehsu/moonbit-binaries/gh-pages/index.json' -OutFile 'index.json'
    Pop-Location
}

function Invoke-SnapCore {
    $CoreEntryPoint = 'https://cli.moonbitlang.com/cores/core-latest.zip'

    Write-Debug "Checking last modified date of moonbit core ..."
    $DateTime = Get-Date "$((Invoke-WebRequest -Method HEAD $CoreEntryPoint).Headers.'Last-Modified')" -Format FileDateTimeUniversal

    [System.Management.Automation.OrderedHashtable]$Index = Get-Content -Path $IndexFile | ConvertFrom-Json -AsHashtable

    if (-not $Index.ContainsKey('core')) {
        $Index.'core' = [ordered]@{
            "last_modified" = $null
            "releases" = @()
        }
    }

    if (!$Force -and $Index.'core'.last_modified -eq $DateTime) {
        Write-Output "Moonbit core is up to date."
        return
    }

    $Index.'core'.last_modified = $DateTime

    Write-Debug "Downloading latest moonbit core ..."
    New-Item -Path "$PSScriptRoot/tmp" -ItemType Directory -Force | Out-Null
    $File = "$PSScriptRoot/tmp/moonbit-core-latest.zip"

    Invoke-WebRequest -Uri $CoreEntryPoint -OutFile $File

    Write-Debug "Getting latest moonbit core version number ..."
    Push-Location "$PSScriptRoot/tmp"
    Expand-Archive -Path $File -DestinationPath "$PSScriptRoot/tmp" -Force
    $MoonModJson = Get-Content -Path "$PSScriptRoot/tmp/core/moon.mod.json" | ConvertFrom-Json
    Pop-Location

    $LatestVersion = $MoonModJson.version
    $Sha256 = (Get-FileHash -Path $File -Algorithm SHA256).Hash.ToLower()

    $LatestRelease = [ordered]@{
        "version" = $LatestVersion
        "name" = "moonbit-core-v$LatestVersion.zip"
        "sha256" = $Sha256
    }

    $Index.'core'.releases = @($LatestRelease)

    Write-Debug "Writing partial index file ..."
    [System.Management.Automation.OrderedHashtable]$PartialIndex = [ordered]@{
        "core" = $Index.'core'
    }

    $PartialIndex | ConvertTo-Json -Depth 100 | Set-Content -Path "$PSScriptRoot/tmp/index-core.json"

    Write-Debug "Copying moonbit core to dist folder ..."
    New-Item -Path "$PSScriptRoot/dist/core" -ItemType Directory -Force | Out-Null
    Copy-Item -Path $File -Destination "$PSScriptRoot/dist/core/" -Force
    "$Sha256  moonbit-core-latest.zip" | Out-File -FilePath "$PSScriptRoot/dist/core/moonbit-core-latest.zip.sha256" -Encoding ascii -Force
    Copy-Item -Path $File -Destination "$PSScriptRoot/dist/core/$($LatestRelease.name)" -Force
    "$Sha256  $($LatestRelease.name)" | Out-File -FilePath "$PSScriptRoot/dist/core/$($LatestRelease.name).sha256" -Encoding ascii -Force
}

function Invoke-SnapBinaries {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Arch,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$EntryPoint
    )

    Write-Debug "Checking last modified date of moonbit binaries ..."
    $DateTime = Get-Date "$((Invoke-WebRequest -Method HEAD $EntryPoint).Headers.'Last-Modified')" -Format FileDateTimeUniversal

    [System.Management.Automation.OrderedHashtable]$Index = Get-Content -Path $IndexFile | ConvertFrom-Json -AsHashtable

    if (-not $Index.ContainsKey($Arch)) {
        $Index.$Arch = [ordered]@{
            "last_modified" = $null
            "releases" = @()
        }
    }

    if (!$Force -and $Index.$Arch.last_modified -eq $DateTime) {
        Write-Output "Moonbit binaries are up to date."
        return
    }

    $Index.$Arch.last_modified = $DateTime

    Write-Debug "Downloading latest moonbit ..."
    New-Item -Path "$PSScriptRoot/tmp" -ItemType Directory -Force | Out-Null
    $Filename = "moonbit-latest-$Arch.tar.gz"
    if ($Arch -eq 'win-x64') {
        $Filename = "moonbit-latest-$Arch.zip"
    }
    $File = "$PSScriptRoot/tmp/$Filename"

    Invoke-WebRequest -Uri $ENTRYPOINT -OutFile $File

    Write-Debug "Getting latest moonbit version number ..."
    Push-Location "$PSScriptRoot/tmp"
    if ($Arch -eq 'win-x64') {
        Expand-Archive -Path $File -DestinationPath "$PSScriptRoot/tmp" -Force
    } else {
        tar -xf $File
        chmod +x ./moonc
    }

    $VersionString = (& ./moonc -v)
    Pop-Location

    if ($VersionString -match 'v([\d.]+)\+([a-f0-9]+)') {
        $LatestVersion = "$($Matches[1])+$($Matches[2])"
        $Sha256 = (Get-FileHash -Path $File -Algorithm SHA256).Hash.ToLower()

        $VersionedFilename = "moonbit-v$LatestVersion-$Arch.tar.gz"
        if ($Arch -eq 'win-x64') {
            $VersionedFilename = "moonbit-v$LatestVersion-$Arch.zip"
        }

        $LatestRelease = [ordered]@{
            "version" = $LatestVersion
            "name" = $VersionedFilename
            "sha256" = $Sha256
        }

        $Index.$Arch.releases = @($LatestRelease)

        Write-Debug "Writing partial index file ..."
        [System.Management.Automation.OrderedHashtable]$PartialIndex = [ordered]@{
            $Arch = $Index.$Arch
        }

        $PartialIndex | ConvertTo-Json -Depth 100 | Set-Content -Path "$PSScriptRoot/tmp/index-$Arch.json"

        Write-Debug "Copying moonbit binaries to dist folder ..."
        New-Item -Path "$PSScriptRoot/dist/latest" -ItemType Directory -Force | Out-Null
        Copy-Item -Path $File -Destination "$PSScriptRoot/dist/latest/" -Force
        "$Sha256  $Filename" | Out-File -FilePath "$PSScriptRoot/dist/latest/$Filename.sha256" -Encoding ascii -Force
        New-Item -Path "$PSScriptRoot/dist/$LatestVersion" -ItemType Directory -Force | Out-Null
        Copy-Item -Path $File -Destination "$PSScriptRoot/dist/$LatestVersion/$VersionedFilename" -Force
        "$Sha256  $VersionedFilename" | Out-File -FilePath "$PSScriptRoot/dist/$LatestVersion/$VersionedFilename.sha256" -Encoding ascii -Force
    } else {
        Write-Error "Failed to get latest moonbit version number"
    }
}

function Invoke-MergeIndex {
    $Index = Get-Content -Path $IndexFile | ConvertFrom-Json -AsHashtable

    @('core', 'darwin-arm64', 'darwin-x64', 'linux-x64', 'win-x64') | ForEach-Object {
        $PartialIndexFile = "$PSScriptRoot/tmp/index-$_.json"
        if (-not (Test-Path $PartialIndexFile)) {
            return
        }
    
        $PartialIndex = Get-Content -Path $PartialIndexFile | ConvertFrom-Json -AsHashtable

        if (-not $Index.ContainsKey($_)) {
            return
        }

        Write-Debug "Merging partial index file 'index-$_.json' ..."
        $Index.$_.last_modified = $PartialIndex.$_.last_modified
        $Index.$_.releases = $($PartialIndex.$_.releases; $Index.$_.releases) | Sort-Object -Unique -Property { $_.version } -Descending
    }
    
    $Index | ConvertTo-Json -Depth 100 | Set-Content -Path $IndexFile
    
}

Invoke-CheckoutDeployment

if ($Merge) {
    Invoke-MergeIndex
} elseif ($SnapToolchain) {
    if ($IsWindows) {
        Invoke-SnapBinaries -Arch 'win-x64' -EntryPoint 'https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.zip'
    }

    if ($IsLinux) {
        Invoke-SnapBinaries -Arch 'linux-x64' -EntryPoint 'https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz'
    }

    if ($IsMacOS) {
        $arch = (uname -sm)
        if ($arch -match 'arm64') {
            Invoke-SnapBinaries -Arch 'darwin-arm64' -EntryPoint 'https://cli.moonbitlang.com/binaries/latest/moonbit-darwin-aarch64.tar.gz'
        } else {
            Invoke-SnapBinaries -Arch 'darwin-x64' -EntryPoint 'https://cli.moonbitlang.com/binaries/latest/moonbit-darwin-x86_64.tar.gz'
        }
    }
} else {
    Invoke-SnapCore
}
