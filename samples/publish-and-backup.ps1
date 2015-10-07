# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

[cmdletbinding(SupportsShouldProcess=$true)]
param($publishProperties, $packOutput, $nugetUrl)

$env:msdeployinstallpath = 'C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\'

# to learn more about this file visit http://go.microsoft.com/fwlink/?LinkId=524327
$publishModuleVersion = '1.0.2-beta2'
function Get-VisualStudio2015InstallPath{
    [cmdletbinding()]
    param()
    process{
        $keysToCheck = @('hklm:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\14.0','hklm:\SOFTWARE\Microsoft\VisualStudio\14.0')
        [string]$vsInstallPath=$null

        foreach($keyToCheck in $keysToCheck){
            if(Test-Path $keyToCheck){
                $vsInstallPath = (Get-itemproperty $keyToCheck -Name InstallDir | select -ExpandProperty InstallDir)
            }

            if($vsInstallPath){
                break;
            }
        }

        $vsInstallPath
    }
}

$defaultPublishSettings = New-Object psobject -Property @{
    LocalInstallDir = ("{0}Extensions\Microsoft\Web Tools\Publish\Scripts\{1}\" -f (Get-VisualStudio2015InstallPath),'1.0.2-beta2' )
}

function Enable-PackageDownloader{
    [cmdletbinding()]
    param(
        $toolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\package-downloader-$publishModuleVersion\",
        $pkgDownloaderDownloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=524325') # package-downloader.psm1
    process{
        if(get-module package-downloader){
            remove-module package-downloader | Out-Null
        }

        if(!(get-module package-downloader)){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory -WhatIf:$false }

            $expectedPath = (Join-Path ($toolsDir) 'package-downloader.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $pkgDownloaderDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($pkgDownloaderDownloadUrl, $expectedPath)
            }
        
            if(!$expectedPath){throw ('Unable to download package-downloader.psm1')}

            'importing module [{0}]' -f $expectedPath | Write-Output
            Import-Module $expectedPath -DisableNameChecking -Force
        }
    }
}

function Enable-PublishModule{
    [cmdletbinding()]
    param()
    process{
        if(get-module publish-module){
            remove-module publish-module | Out-Null
        }

        if(!(get-module publish-module)){
            $localpublishmodulepath = Join-Path $defaultPublishSettings.LocalInstallDir 'publish-module.psm1'
            if(Test-Path $localpublishmodulepath){
                'importing module [publish-module="{0}"] from local install dir' -f $localpublishmodulepath | Write-Verbose
                Import-Module $localpublishmodulepath -DisableNameChecking -Force
                $true
            }
        }
    }
}

try{

    if (!(Enable-PublishModule)){
        Enable-PackageDownloader
        Enable-NuGetModule -name 'publish-module' -version $publishModuleVersion -nugetUrl $nugetUrl
    }

    'Calling Publish-AspNet' | Write-Verbose
    # call Publish-AspNet to perform the publish operation
    Publish-AspNet -publishProperties $publishProperties -packOutput $packOutput -Verbose

	# publish with file system to backup the contents after publish
	$backupdir='c:\temp\publish\backup'
	'backing up the site to {0}' -f $backupdir | Write-Output
	Publish-AspNet -packOutput $packOutput -publishProperties @{'WebPublishMethod'='FileSystem';'publishUrl'="$backupdir"}
}
catch{
    "An error occured during publish.`n{0}" -f $_.Exception.Message | Write-Error
}