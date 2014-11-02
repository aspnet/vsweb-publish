[cmdletbinding()]
param(
    $versionToInstall = '0.0.1-beta',
    $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
    $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
)
$script:moduleName = 'publish-module'
# originally based off of the scrit at http://psget.net/GetPsGet.ps1
function Install-PSBuild {
    $modsFolder= GetPsModulesPath
    $destFolder = (join-path $modsFolder 'psbuild\')
    $destFile = (join-path $destFolder 'psbuild.psm1')
    
    if(!(test-path $destFolder)){
        new-item -path $destFolder -ItemType Directory -Force | out-null
    }

    # this will download using nuget if its not in localappdata
    $psbPsm1File = GetPsBuildPsm1

    # copy the folder to the modules folder

    Copy-Item -Path "$($psbPsm1File.Directory.FullName)\*"  -Destination $destFolder -Recurse

    if ((Get-ExecutionPolicy) -eq "Restricted"){
        Write-Warning @"
Your execution policy is $executionPolicy, this means you will not be able import or use any scripts including modules.
To fix this change your execution policy to something like RemoteSigned.

        PS> Set-ExecutionPolicy RemoteSigned

For more information execute:
        
        PS> Get-Help about_execution_policies

"@
    }
    else{
        Import-Module -Name $modsFolder\psbuild -DisableNameChecking -Force
    }

    Write-Host "psbuild is installed and ready to use" -Foreground Green
    Write-Host @"
USAGE:
    PS> Invoke-MSBuild 'C:\temp\msbuild\msbuild.proj'
    PS> Invoke-MSBuild C:\temp\msbuild\path.proj -properties (@{'OutputPath'='c:\ouput\';'visualstudioversion'='12.0'}) -extraArgs '/nologo'

For more details:
    get-help Invoke-MSBuild
Or visit http://msbuildbook.com/psbuild
"@
}

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
        $versionToInstall = '0.0.1-beta',
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
            # nuget install psbuild -Version 0.0.3-beta -Prerelease -OutputDirectory C:\temp\nuget\out\
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

$publishModuleFile = GetPublishModuleFile
'Importing publish-module from [{0}]' -f $publishModuleFile | Write-Verbose
Import-Module $publishModuleFile -DisableNameChecking -Force