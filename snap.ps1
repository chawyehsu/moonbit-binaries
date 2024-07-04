#!/usr/bin/env pwsh
#Requires -Version 7

Set-StrictMode -Version Latest

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

    $Index = Get-Content -Path $IndexFile | ConvertFrom-Json

    if (-not [bool]($Index | Get-Member -MemberType NoteProperty) -or ($Index.PSObject.Properties.Name -notcontains 'core')) {
        $Index | Add-Member -MemberType NoteProperty -Name 'core' -Value @{
            "last_modified" = $null
            "releases" = @()
        }
    }

    if ($Index.'core'.last_modified -eq $DateTime) {
        Write-Output "Moonbit core is up to date."
        return
    }

    $Index.'core'.last_modified = $DateTime

    Write-Debug "Downloading latest moonbit core ..."
    New-Item -Path "$PSScriptRoot/tmp" -ItemType Directory -Force | Out-Null
    $File = "$PSScriptRoot/tmp/moonbit-core-latest.zip"

    if (-not (Test-Path $File)) {
        Invoke-WebRequest -Uri $CoreEntryPoint -OutFile $File
    }

    Write-Debug "Getting latest moonbit core version number ..."
    Push-Location "$PSScriptRoot/tmp"
    Expand-Archive -Path $File -DestinationPath "$PSScriptRoot/tmp" -Force
    $MoonModJson = Get-Content -Path "$PSScriptRoot/tmp/core/moon.mod.json" | ConvertFrom-Json
    Pop-Location

    $LatestVersion = $MoonModJson.version
    $Sha256 = (Get-FileHash -Path $File -Algorithm SHA256).Hash.ToLower()

    $LatestRelease = @{
        "version" = $LatestVersion
        "name" = "moonbit-core-v$LatestVersion.zip"
        "sha256" = $Sha256
    }

    $Index.'core'.releases += $LatestRelease

    Write-Debug "Updating index file ..."
    $Index | ConvertTo-Json -Depth 100 | Set-Content -Path $IndexFile

    Write-Debug "Copying moonbit core to dist folder ..."
    New-Item -Path "$PSScriptRoot/dist/core" -ItemType Directory -Force | Out-Null
    Copy-Item -Path $File -Destination "$PSScriptRoot/dist/core/" -Force
    "$Sha256  moonbit-core-latest.zip" | Out-File -FilePath "$PSScriptRoot/dist/core/moonbit-core-latest.zip.sha256" -Encoding ascii -Force
    Copy-Item -Path $File -Destination "$PSScriptRoot/dist/core/$($LatestRelease.name)" -Force
    "$Sha256  $($LatestRelease.name)" | Out-File -FilePath "$PSScriptRoot/dist/core/$($LatestRelease.name).sha256" -Encoding ascii -Force
}

Invoke-CheckoutDeployment
Invoke-SnapCore
