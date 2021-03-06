#
# This script requires internal-only access to the code which generates ANCM installers.
#

#requires -version 4
[cmdletbinding()]
param(
    [string]$Configuration = 'Debug',
    [Parameter(Mandatory = $true)]
    [Alias("x86")]
    [string]$Runtime86Zip,
    [Parameter(Mandatory = $true)]
    [Alias("x64")]
    [string]$Runtime64Zip,
    [string]$BuildNumber = 't000',

    [string]$AccessTokenSuffix = $null,
    [string]$AssetRootUrl = $null,

    [switch]$clean
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path "$PSScriptRoot/../../../"
Import-Module -Scope Local "$repoRoot/scripts/common.psm1" -Force
$msbuild = Get-MSBuildPath -Prerelease -requires 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'

$harvestRoot = "$repoRoot/obj/sfx/"
if ($clean) {
    Remove-Item -Recurse -Force $harvestRoot -ErrorAction Ignore | Out-Null
}

New-Item "$harvestRoot/x86", "$harvestRoot/x64" -ItemType Directory -ErrorAction Ignore | Out-Null

if (-not (Test-Path "$harvestRoot/x86/shared/")) {
    Expand-Archive $Runtime86Zip -DestinationPath "$harvestRoot/x86"
}

if (-not (Test-Path "$harvestRoot/x64/shared/")) {
    Expand-Archive $Runtime64Zip -DestinationPath "$harvestRoot/x64"
}

Push-Location $PSScriptRoot
try {
    Invoke-Block { & $msbuild `
            tasks/InstallerTasks.csproj `
            -nologo `
            -m `
            -v:m `
            -nodeReuse:false `
            -restore `
            -t:Build `
            "-p:Configuration=$Configuration"
    }

    [string[]] $msbuildArgs = @()

    if ($clean) {
        $msbuildArgs += '-t:Clean'
    }

    if ($AssetRootUrl) {
        $msbuildArgs += "-p:DotNetAssetRootUrl=$AssetRootUrl"
    }

    if ($AccessTokenSuffix) {
        $msbuildArgs += "-p:DotNetAccessTokenSuffix=$AccessTokenSuffix"
    }

    $msbuildArgs += '-t:Build'

    Invoke-Block { & $msbuild `
            WindowsInstallers.proj `
            -restore `
            -nologo `
            -m `
            -v:m `
            -nodeReuse:false `
            -clp:Summary `
            "-p:SharedFrameworkHarvestRootPath=$repoRoot/obj/sfx/" `
            "-p:Configuration=$Configuration" `
            "-p:BuildNumber=$BuildNumber" `
            -bl `
            @msbuildArgs
    }
}
finally {
    Pop-Location
}
