[cmdletbinding()]
param(
    [Parameter(Position=0)]
    $versionToInstall = '0.0.7-beta',
    [Parameter(Position=1)]
    $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
    [Parameter(Position=2)]
    $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
)
$script:moduleName = 'publish-module'

# see if the particular version is installed under localappdata
function GetPublishModuleFile{
    [cmdletbinding()]
    param(
        $versionToInstall = '0.0.7-beta',
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
        $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
    )
    process{
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null
        }
        $folderPath = Ensure-PsNuGetPackageIsAvailable -name 'publish-module' -version $versionToInstall 

        $psm1File = (Join-Path $folderPath 'tools\publish-module.psm1')

        if(!$psm1file){ 
            throw "$script:moduleName not found, and was not downloaded successfully. sorry." 
        }

        $psm1file
    }
}

function Ensure-PsNuGetLoaded{
    [cmdletbinding()]
    param($toolsDir = "$env:LOCALAPPDATA\LigerShark\psnuget\",
        $psNuGetDownloadUrl = 'https://raw.githubusercontent.com/sayedihashimi/publish-module/master/ps-nuget.psm1')
    process{
        if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory }

        $expectedPath = (Join-Path ($toolsDir) 'ps-nuget.psm1')
        if(!(Test-Path $expectedPath)){
            'Downloading [{0}] to [{1}]' -f $psNuGetDownloadUrl,$expectedPath | Write-Verbose
            (New-Object System.Net.WebClient).DownloadFile($psNuGetDownloadUrl, $expectedPath)
        }
        
        if(!$expectedPath){throw ('Unable to download ps-nuget.psm1')}

        if(!(get-module 'ps-nuget')){
            'importing module into global [{0}]' -f $expectedPath | Write-Output
            Import-Module $expectedPath -DisableNameChecking -Force -Scope Global
        }
    }
}

###########################################
# Begin script
###########################################

Ensure-PsNuGetLoaded

$publishModuleFile = GetPublishModuleFile -versionToInstall $versionToInstall -toolsDir $toolsDir -nugetDownloadUrl $nugetDownloadUrl
if(Get-Module publish-module){
    Remove-Module publish-module -Force | Out-Null
}
'Importing publish-module from [{0}]' -f $publishModuleFile | Write-Verbose
Import-Module $publishModuleFile -DisableNameChecking -Force -Global