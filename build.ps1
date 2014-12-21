[cmdletbinding(DefaultParameterSetName ='build')]
param(
    [Parameter(ParameterSetName='build',Position=0)]
    [switch]$build,
    [Parameter(ParameterSetName='updateversion',Position=0)]
    [switch]$updateversion,
    [Parameter(ParameterSetName='createnugetlocalrepo',Position=0)]
    [switch]$createnugetlocalrepo,

    [Parameter(ParameterSetName='build',Position=1)]
    [switch]$publishToNuget,

    [Parameter(ParameterSetName='build',Position=2)]
    [string]$nugetApiKey = ($env:NuGetApiKey),

    [Parameter(ParameterSetName='updateversion',Position=1,Mandatory=$true)]
    [string]$oldversion,

    [Parameter(ParameterSetName='updateversion',Position=2,Mandatory=$true)]
    [string]$newversion,

    [Parameter(ParameterSetName='createnugetlocalrepo',Position=1)]
    [bool]$updateNugetExe = $false
)

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")

$global:publishmodbuildsettings = New-Object PSObject -Property @{
    LocalNuGetFeedPath = ('{0}\LigerShark\publish-module\nugetfeed' -f $env:localappdata)
}

<#
.SYNOPSIS
    If nuget is in the tools
    folder then it will be downloaded there.
#>
function Get-Nuget(){
    [cmdletbinding()]
    param(
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
        $nugetDownloadUrl = 'http://nuget.org/nuget.exe'
    )
    process{
        try{
            $nugetDestPath = Join-Path -Path $toolsDir -ChildPath nuget.exe
        
            if(!(Test-Path $nugetDestPath)){
                $nugetDir = ([System.IO.Path]::GetDirectoryName($nugetDestPath))
                if(!(Test-Path $nugetDir)){
                    New-Item -Path $nugetDir -ItemType Directory | Out-Null
                }

                'Downloading nuget.exe' | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($nugetDownloadUrl, $nugetDestPath)

                # double check that is was written to disk
                if(!(Test-Path $nugetDestPath)){
                    throw 'unable to download nuget'
                }
            }

            # return the path of the file
            $nugetDestPath
        }
        catch{
            throw ("Unable to download/find nuget.exe. Error:`n{0}" -f $_.Exception.Message)            
        }
    }
}

function PublishNuGetPackage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$nugetPackages,

        [Parameter(Mandatory=$true)]
        $nugetApiKey
    )
    process{
        foreach($nugetPackage in $nugetPackages){
            $pkgPath = (get-item $nugetPackage).FullName
            $cmdArgs = @('push',$pkgPath,$nugetApiKey,'-NonInteractive')

            'Publishing nuget package with the following args: [nuget.exe {0}]' -f ($cmdArgs -join ' ') | Write-Verbose
            &(Get-Nuget) $cmdArgs
        }
    }
}


function Build{
    $outputRoot = Join-Path $scriptDir "OutputRoot"
    $nugetDevRepo = 'C:\temp\nuget\localrepo\'

    if(!(Test-Path $outputRoot)){
        New-Item $outputRoot -ItemType Directory
    }

    $outputRoot = (Get-Item $outputRoot).FullName
    # call nuget to create the package

    $nuspecFiles = @((get-item(Join-Path $scriptDir "publish-module.nuspec")).FullName)
    $nuspecFiles += (get-item(Join-Path $scriptDir "publish-module-blob.nuspec")).FullName
    $nuspecFiles += (get-item(Join-Path $scriptDir "getnuget.nuspec")).FullName

    $nuspecFiles | ForEach-Object {
        $nugetArgs = @('pack',$_,'-o',$outputRoot)
        'Calling nuget.exe with the command:[nuget.exe {0}]' -f  ($nugetArgs -join ' ') | Write-Verbose
        &(Get-Nuget) $nugetArgs    
    }

    if(Test-Path $nugetDevRepo){
        Get-ChildItem -Path $outputRoot '*.nupkg' | Copy-Item -Destination $nugetDevRepo
    }

    if($publishToNuget){
        (Get-ChildItem -Path $outputRoot '*.nupkg').FullName | PublishNuGetPackage -nugetApiKey $nugetApiKey
    }
}

function Enable-GetNuGet{
    [cmdletbinding()]
    param($toolsDir = "$env:LOCALAPPDATA\LigerShark\tools\getnuget\",
        $getNuGetDownloadUrl = 'https://raw.githubusercontent.com/sayedihashimi/publish-module/master/getnuget.psm1')
    process{
        if(!(get-module 'getnuget')){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory -WhatIf:$false }

            $expectedPath = (Join-Path ($toolsDir) 'getnuget.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $getNuGetDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($getNuGetDownloadUrl, $expectedPath)
                if(!$expectedPath){throw ('Unable to download getnuget.psm1')}
            }

            'importing module [{0}]' -f $expectedPath | Write-Verbose
            Import-Module $expectedPath -DisableNameChecking -Force -Scope Global
        }
    }
}

function UpdateVersion{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [ValidateScript({})]
        [string]$oldversion,

        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty]
        [string]$newversion,

        [Parameter(Position=2)]
        [string]$filereplacerVersion = '0.2.0-beta'
    )
    process{
        'Updating version from [{0}] to [{1}]' -f $oldversion,$newversion | Write-Verbose
        Enable-GetNuGet
        'trying to load file replacer' | Write-Verbose
        Enable-NuGetModule -name 'file-replacer' -version $filereplacerVersion

        $folder = $scriptDir
        $include = '*.nuspec;*.ps*1'
        # In case the script is in the same folder as the files you are replacing add it to the exclude list
        $exclude = "$($MyInvocation.MyCommand.Name);"
        $replacements = @{
            $oldversion=$newversion
        }
        $logger = New-Object -TypeName System.Text.StringBuilder
        Replace-TextInFolder -folder $folder -include $include -exclude $exclude -replacements $replacements | Write-Verbose
        'Replacement complete' | Write-Verbose
    }
}

function GetFolderCreateIfNotExists{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$folderPath
    )
    process{
        foreach($folder in $folderPath){
            if(!(Test-Path $folderPath)){
                New-Item -Path $folderPath -ItemType Directory | out-null
            }

            (Get-Item $folderPath).FullName
        }
    }
}

function CreateLocalNuGetRepo{
    [cmdletbinding()]
    param($updateNugetExe = $false)
    process{
        $nugetFolder = (GetFolderCreateIfNotExists $global:publishmodbuildsettings.LocalNuGetFeedPath)
    
        $pkgsConfigContent = @'
<?xml version="1.0" encoding="utf-8"?>
<packages>
    <package id="publish-module" />
    <package id="publish-module-blob" />
</packages>
'@
        $pkgsConfigPath = ("$nugetFolder\packages.config")
        if(Test-Path $pkgsConfigPath){
            rm -r $pkgsConfigPath
        }

        $pkgsConfigContent | Set-Content -Path $pkgsConfigPath

        if($updateNugetExe){
            # update nuget.exe first
            &(Get-NuGet) @('update','-self')
            Copy-Item -Path (Get-Nuget) -Destination $nugetFolder
        }
        # copy nuget.exe over there and update it
        $pkgsToInstall = @('publish-module','publish-module-blob')

        # call nuget to restore the packages that we want
        $nugetArgs = @('install',$pkgsConfigPath,'-o',$nugetFolder)
        'Calling nuget.exe with the following [nuget.exe {0}]' -f ($nugetArgs -join ',') | Write-Verbose
        &(Get-Nuget) $nugetArgs
    }
}

# Begin script here

if(!$updateversion -and !$createnugetlocalrepo){
    # build is the default option
    $build = $true
}

if($build){ Build }
elseif($updateversion){ UpdateVersion }
elseif($createnugetlocalrepo){ CreateLocalNuGetRepo }
else{
    $cmds = @('-build','-updateversion','-createnugetlocalrepo')
    'No command specified, please pass in one of the following [{0}]' -f ($cmds -join ' ') | Write-Error
}

