#!/usr/bin/env pwsh
#Requires -Version 7

<#
.SYNOPSIS
    Download official moonbit install scripts.
.DESCRIPTION
    Download official moonbit install scripts for reference.
#>

Set-StrictMode -Version Latest

$DebugPreference = 'Continue'

function Initialize-ReferenceDir {
    $ReferenceDir = "$PSScriptRoot/../references"
    if (Test-Path $ReferenceDir) {
        Write-Debug "Removing existing reference directory: $ReferenceDir"
        Remove-Item -Path $ReferenceDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $ReferenceDir -Force | Out-Null
    return $ReferenceDir
}

function Get-OfficialScript {
    $ReferenceDir = Initialize-ReferenceDir
    $ScriptUrls = @(
        'https://cli.moonbitlang.com/install/powershell.ps1',
        'https://cli.moonbitlang.com/install/unix.sh'
    )

    foreach ($url in $ScriptUrls) {
        $fileName = [System.IO.Path]::GetFileName($url)
        $destinationPath = Join-Path -Path $ReferenceDir -ChildPath $fileName
        Invoke-WebRequest -Uri $url -OutFile $destinationPath
        Write-Output "Downloaded $url"
    }
}

Get-OfficialScript
