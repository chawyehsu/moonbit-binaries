#!/usr/bin/env pwsh
#Requires -Version 7

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('bleeding', 'latest', 'nightly')]
    [string]$Channel = 'latest'
)

Set-StrictMode -Version Latest

$Channel = $Channel
$GHA_ARTIFACTS_DIR = "$PSScriptRoot/../tmp/gha-artifacts"

$VERSION = '0.6.29+9037370fc'

function Get-AllToolchain {
    $tag = switch ($Channel) {
        'bleeding' { 'bleeding' }
        'latest' { $VERSION }
        'nightly' {
            $date = Get-Date -Format 'yyyy-MM-dd'
            "nightly-$date"
        } # Fake date for nightly
    }

    $TOOLCHAIN_URLS = @(
        @{
            arch     = 'aarch64-apple-darwin'
            url      = "https://cli.moonbitlang.com/binaries/$Channel/moonbit-darwin-aarch64.tar.gz"
            filename = "moonbit-$tag-aarch64-apple-darwin.tar.gz"
        }
        @{
            arch     = 'x86_64-unknown-linux'
            url      = "https://cli.moonbitlang.com/binaries/$Channel/moonbit-linux-x86_64.tar.gz"
            filename = "moonbit-$tag-x86_64-unknown-linux.tar.gz"
        }
        @{
            arch     = 'x86_64-pc-windows'
            url      = "https://cli.moonbitlang.com/binaries/$Channel/moonbit-windows-x86_64.zip"
            filename = "moonbit-$tag-x86_64-pc-windows.zip"
        }
    )

    Push-Location $GHA_ARTIFACTS_DIR

    $TOOLCHAIN_URLS | ForEach-Object {
        $arch = $_.arch
        $url = $_.url
        $filename = $_.filename

        Write-Host "Downloading toolchain for $arch from $url"

        try {
            Invoke-WebRequest -Uri $url -OutFile $filename
        } catch {
            Pop-Location
            Write-Error "Failed to download toolchain for $arch from $url"
            exit 1
        }

        $toolchainPkgSha256 = (Get-FileHash -Path $filename -Algorithm SHA256).Hash.ToLower()

        $componentToolchain = [ordered]@{
            version  = $VERSION
            name     = 'toolchain'
            date     = (Get-Date -Format 'yyyy-MM-dd')
            file     = $filename
            'sha256' = $toolchainPkgSha256
        }

        Write-Debug 'Saving toolchain component json file ...'
        New-Item -Path $GHA_ARTIFACTS_DIR -ItemType Directory -Force | Out-Null
        $componentToolchain | ConvertTo-Json -Depth 99 | Set-Content -Path "$GHA_ARTIFACTS_DIR/component-moonbit-toolchain-$Arch.json"

        Write-Debug 'Saving moonbit toolchain pkg ...'
        "$toolchainPkgSha256  *$($componentToolchain.file)" | Out-File -FilePath "$GHA_ARTIFACTS_DIR/$($componentToolchain.file).sha256" -Encoding ascii -Force
    }

    Pop-Location
}

Remove-Item -Path "$GHA_ARTIFACTS_DIR" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path "$GHA_ARTIFACTS_DIR" -ItemType Directory -Force | Out-Null

Get-AllToolchain
