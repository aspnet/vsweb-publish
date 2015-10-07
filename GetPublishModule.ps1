# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

[cmdletbinding()]
param(
    [Parameter(Position=0)]
    $versionToInstall = '1.0.2-beta2',
    [Parameter(Position=1)]
    $toolsDir = ("$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\tools\"),
    [Parameter(Position=2)]
    $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
)
$script:moduleName = 'publish-module'

# see if the particular version is installed under localappdata
function GetPublishModuleFile{
    [cmdletbinding()]
    param(
        $versionToInstall = '1.0.2-beta2',
        $toolsDir = ("$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\tools\"),
        $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
    )
    process{
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null
        }
        $folderPath = Enable-PackageDownloader -name 'publish-module' -version $versionToInstall 

        $psm1File = (Join-Path $folderPath 'tools\publish-module.psm1')

        if(!$psm1file){ 
            throw "$script:moduleName not found, and was not downloaded successfully. sorry." 
        }

        $psm1file
    }
}

function Enable-PackageDownloader{
    [cmdletbinding()]
    param($toolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\package-downloader\",
        $pkgDownloaderDownloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=524325') # package-downloader.psm1
    process{
        if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory }

        $expectedPath = (Join-Path ($toolsDir) 'package-downloader.psm1')
        if(!(Test-Path $expectedPath)){
            'Downloading [{0}] to [{1}]' -f $pkgDownloaderDownloadUrl,$expectedPath | Write-Verbose
            (New-Object System.Net.WebClient).DownloadFile($pkgDownloaderDownloadUrl, $expectedPath)
        }
        
        if(!$expectedPath){throw ('Unable to download package-downloader.psm1')}

        if(!(get-module package-downloader)){
            'importing module into global [{0}]' -f $expectedPath | Write-Output
            Import-Module $expectedPath -DisableNameChecking -Force -Scope Global
        }
    }
}

###########################################
# Begin script
###########################################

Enable-PackageDownloader

$publishModuleFile = GetPublishModuleFile -versionToInstall $versionToInstall -toolsDir $toolsDir -nugetDownloadUrl $nugetDownloadUrl
if(Get-Module publish-module){
    Remove-Module publish-module -Force | Out-Null
}
'Importing publish-module from [{0}]' -f $publishModuleFile | Write-Verbose
Import-Module $publishModuleFile -DisableNameChecking -Force -Global