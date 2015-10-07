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

function Publish-FolderToBlobStorage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateScript({Test-Path $_ -PathType Container})] 
        $folder,
        [Parameter(Mandatory=$true,Position=1)]
        $storageAcctName,
        [Parameter(Mandatory=$true,Position=2)]
        $storageAcctKey,
        [Parameter(Mandatory=$true,Position=3)]
        $containerName
    )
    begin{
        'Publishing folder to blob storage. [folder={0},storageAcctName={1},storageContainer={2}]' -f $folder,$storageAcctName,$containerName | Write-Output
        Push-Location
        Set-Location $folder
        $destContext = New-AzureStorageContext -StorageAccountName $storageAcctName -StorageAccountKey $storageAcctKey
    }
    end{ Pop-Location }
    process{
        $allFiles = (Get-ChildItem $folder -Recurse -File).FullName

        foreach($file in $allFiles){
            $relPath = (Resolve-Path $file -Relative).TrimStart('.\')
            "relPath: [$relPath]" | Write-Output

            Set-AzureStorageBlobContent -Blob $relPath -File $file -Container $containerName -Context $destContext
        }
    }
}

try{

    if (!(Enable-PublishModule)){
        Enable-PackageDownloader
        Enable-NuGetModule -name 'publish-module' -version $publishModuleVersion -nugetUrl $nugetUrl
    }

	'Registering blob storage handler' | Write-Verbose
	Register-AspnetPublishHandler -name 'BlobStorage' -handler {
		[cmdletbinding()]
		param(
			[Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
			$publishProperties,
			[Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
			$packOutput
		)
    
		'[op={0},san={1},con={2}' -f $packOutput,$publishProperties['StorageAcctName'],$publishProperties['StorageContainer'] | Write-Output

		Publish-FolderToBlobStorage -folder $packOutput -storageAcctName $publishProperties['StorageAcctName'] -storageAcctKey $publishProperties['StorageAcctKey'] -containerName $publishProperties['StorageContainer']
	}	

    'Calling Publish-AspNet' | Write-Verbose
    # call Publish-AspNet to perform the publish operation
    Publish-AspNet -publishProperties $publishProperties -packOutput $packOutput -Verbose
}
catch{
    "An error occured during publish.`n{0}" -f $_.Exception.Message | Write-Error
}