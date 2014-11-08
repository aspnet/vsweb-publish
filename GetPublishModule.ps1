[cmdletbinding()]
param(
    [Parameter(Position=0)]
    $versionToInstall = '0.0.5-beta',
    [Parameter(Position=1)]
    $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
    [Parameter(Position=2)]
    $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
)
$script:moduleName = 'publish-module'

<#
.SYNOPSIS
    This will return nuget from the $toolsDir. If it is not there then it
    will automatically be downloaded before the call completes.
#>
function Get-Nuget(){
    [cmdletbinding()]
    param(
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
        $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
    )
    process{
        $nugetDestPath = Join-Path -Path $toolsDir -ChildPath nuget.exe
        
        if(!(Test-Path $nugetDestPath)){
            $nugetDir = ([System.IO.Path]::GetDirectoryName($nugetDestPath))
            if(!(Test-Path $nugetDir)){
                New-Item -Path $nugetDir -ItemType Directory | Out-Null
            }

            'Downloading nuget.exe' | Write-Verbose
            (New-Object System.Net.WebClient).DownloadFile($nugetDownloadUrl, $nugetDestPath) | Out-Null

            # double check that is was written to disk
            if(!(Test-Path $nugetDestPath)){
                throw 'unable to download nuget'
            }
        }

        # return the path of the file
        $nugetDestPath
    }
}

# see if the particular version is installed under localappdata
function GetPublishModuleFile{
    [cmdletbinding()]
    param(
        $versionToInstall = '0.0.5-beta',
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
        $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
    )
    process{
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null
        }

        $psm1file = (Get-ChildItem -Path ("$toolsDir\{0}.{1}" -f $script:moduleName, $versionToInstall) -Include ("{0}.psm1" -f $script:moduleName) -Recurse -ErrorAction SilentlyContinue | Sort-Object -Descending -ErrorAction SilentlyContinue | Select-Object -First 1 -ErrorAction SilentlyContinue)

        if(!$psm1file){
            "Downloading $script:moduleName to the toolsDir" | Write-Verbose
            # nuget install psbuild -Version 0.0.5-beta -Prerelease -OutputDirectory C:\temp\nuget\out\
            $cmdArgs = @('install',$script:moduleName,'-Version',$versionToInstall,'-Prerelease','-OutputDirectory',(Resolve-Path $toolsDir).ToString())

            $nugetPath = (Get-Nuget -toolsDir $toolsDir -nugetDownloadUrl $nugetDownloadUrl)
            'Calling nuget to install $script:moduleName with the following args. [{0} {1}]' -f $nugetPath, ($cmdArgs -join ' ') | Write-Verbose
            &$nugetPath $cmdArgs | Out-Null

            $psm1file = (Get-ChildItem -Path ("$toolsDir\{0}.{1}" -f $script:moduleName, $versionToInstall) -Include ("{0}.psm1" -f $script:moduleName) -Recurse -ErrorAction SilentlyContinue | Sort-Object -Descending -ErrorAction SilentlyContinue | Select-Object -First 1 -ErrorAction SilentlyContinue)
        }

        if(!$psm1file){ 
            throw "$script:moduleName not found, and was not downloaded successfully. sorry." 
        }

        $psm1file
    }
}

###########################################
# Begin script
###########################################

$publishModuleFile = GetPublishModuleFile -versionToInstall $versionToInstall -toolsDir $toolsDir -nugetDownloadUrl $nugetDownloadUrl
if(Get-Module publish-module){
    Remove-Module publish-module -Force | Out-Null
}
'Importing publish-module from [{0}]' -f $publishModuleFile | Write-Verbose
Import-Module $publishModuleFile -DisableNameChecking -Force