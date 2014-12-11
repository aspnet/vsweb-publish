[cmdletbinding(DefaultParameterSetName ='build')]
param(
    [Parameter(Position=0)]
    [ValidateSet('build','create-local-nuget-repo')]
    [Parameter(ParameterSetName='build')]
    [string]$action='build',

    [Parameter(ParameterSetName='create-local-nuget-repo',Position=1)]
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
}

function DoBuild{
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

switch($action){
    'build' {DoBuild}
    'create-local-nuget-repo' {CreateLocalNuGetRepo}
    'default' {throw ('Unknown value for action: [{0}]' -f $action)}
}

