# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

[cmdletbinding(DefaultParameterSetName ='build')]
param(
    # actions
    [Parameter(ParameterSetName='build',Position=0)]
    [switch]$build,
    [Parameter(ParameterSetName='clean',Position=0)]
    [switch]$clean,
    [Parameter(ParameterSetName='getversion',Position=0)]
    [switch]$getversion,
    [Parameter(ParameterSetName='setversion',Position=0)]
    [switch]$setversion,
    [Parameter(ParameterSetName='createnugetlocalrepo',Position=0)]
    [switch]$createnugetlocalrepo,

    # build parameters
    [Parameter(ParameterSetName='build',Position=1)]
    [switch]$cleanBeforeBuild,

    [Parameter(ParameterSetName='build',Position=2)]
    [switch]$publishToNuget,

    [Parameter(ParameterSetName='build',Position=3)]
    [string]$nugetApiKey = ($env:NuGetApiKey),

    [Parameter(ParameterSetName='build',Position=4)]
    [string]$nugetUrl = $null,

    [Parameter(ParameterSetName='build',Position=5)]
    [switch]$skipTests,

    # setversion parameters
    [Parameter(ParameterSetName='setversion',Position=1,Mandatory=$true)]
    [string]$newversion,

    # createnugetlocalrepo parameters
    [Parameter(ParameterSetName='createnugetlocalrepo',Position=1)]
    [bool]$updateNugetExe = $false
)

$env:IsDeveloperMachine=$true

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
function Get-Nuget{
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
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [string]$nugetPackages,

        [Parameter(Position=1)]
        $nugetApiKey,

        [Parameter(Position=2)]
        [string]$nugetUrl
    )
    process{
        foreach($nugetPackage in $nugetPackages){
            $pkgPath = (get-item $nugetPackage).FullName
            $cmdArgs = @('push',$pkgPath,$nugetApiKey,'-NonInteractive')
            
            if($nugetUrl -and !([string]::IsNullOrWhiteSpace($nugetUrl))){
                $cmdArgs += "-source"
                $cmdArgs += $nugetUrl
            }

            'Publishing nuget package with the following args: [nuget.exe {0}]' -f ($cmdArgs -join ' ') | Write-Verbose
            &(Get-Nuget) $cmdArgs
        }
    }
}

function Clean{
    [cmdletbinding()]
    param()
    process{
        $outputRoot = Join-Path $scriptDir "OutputRoot"
        if((Test-Path $outputRoot)){
            'Removing directory: [{0}]' -f $outputRoot | Write-Output
            Remove-Item $outputRoot -Recurse -Force
        }
        else{
            'Output folder [{0}] doesn''t exist skipping deletion' -f $outputRoot | Write-Output
        }
    }
}

function Build{
    [cmdletbinding()]
    param()
    process{
        'Starting build' | Write-Output
        if($publishToNuget){ $cleanBeforeBuild = $true }

        if($cleanBeforeBuild){
            Clean
        }

        $outputRoot = Join-Path $scriptDir "OutputRoot"
        $nugetDevRepo = 'C:\temp\nuget\localrepo\'

        if(!(Test-Path $outputRoot)){
            'Creating output folder [{0}]' -f $outputRoot | Write-Output
            New-Item $outputRoot -ItemType Directory
        }

        $outputRoot = (Get-Item $outputRoot).FullName
        # call nuget to create the package

        $nuspecFiles = @((get-item(Join-Path $scriptDir "publish-module.nuspec")).FullName)
        $nuspecFiles += (get-item(Join-Path $scriptDir "publish-module-blob.nuspec")).FullName
        $nuspecFiles += (get-item(Join-Path $scriptDir "package-downloader.nuspec")).FullName

        $nuspecFiles | ForEach-Object {
            $nugetArgs = @('pack',$_,'-o',$outputRoot)
            'Calling nuget.exe with the command:[nuget.exe {0}]' -f  ($nugetArgs -join ' ') | Write-Output
            &(Get-Nuget) $nugetArgs    
        }

        if(Test-Path $nugetDevRepo){
            Get-ChildItem -Path $outputRoot '*.nupkg' | Copy-Item -Destination $nugetDevRepo
        }

        # push appveyor artifacts, the e2e tests use them
        if((get-command Push-AppveyorArtifact -ErrorAction SilentlyContinue)){
            (Get-ChildItem -Path $outputRoot '*.nupkg').FullName | % { Push-AppveyorArtifact $_ }
        }
        
        if(!$skipTests){
            Run-Tests
        }

        if($publishToNuget){
            (Get-ChildItem -Path $outputRoot '*.nupkg').FullName | PublishNuGetPackage -nugetApiKey $nugetApiKey -nugetUrl $nugetUrl
        }
    }
}

function Enable-PackageDownloader{
    [cmdletbinding()]
    param($toolsDir = "$env:LOCALAPPDATA\LigerShark\tools\package-downloader\",
        $pkgDownloaderDownloadUrl = 'https://raw.githubusercontent.com/aspnet/vsweb-publish/master/package-downloader.psm1')
    process{
        if(!(get-module package-downloader)){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory -WhatIf:$false }

            $expectedPath = (Join-Path ($toolsDir) 'package-downloader.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $pkgDownloaderDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($pkgDownloaderDownloadUrl, $expectedPath)
                if(!$expectedPath){throw ('Unable to download package-downloader.psm1')}
            }

            'importing module [{0}]' -f $expectedPath | Write-Verbose
            Import-Module $expectedPath -DisableNameChecking -Force -Scope Global
        }
    }
}

<#
.SYNOPSIS 
This will inspect the publsish nuspec file and return the value for the Version element.
#>
function GetExistingVersion{
    [cmdletbinding()]
    param(
        [ValidateScript({test-path $_ -PathType Leaf})]
        $nuspecFile = (Join-Path $scriptDir 'publish-module.nuspec')
    )
    process{
        ([xml](Get-Content $nuspecFile)).package.metadata.version
    }
}

function Set-Version{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$newversion,

        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]$oldversion = (GetExistingVersion),

        [Parameter(Position=2)]
        [string]$filereplacerVersion = '0.2.0-beta'
    )
    process{
        'Updating version from [{0}] to [{1}]' -f $oldversion,$newversion | Write-Verbose
        Enable-PackageDownloader
        'trying to load file replacer' | Write-Verbose
        Enable-NuGetModule -name 'file-replacer' -version $filereplacerVersion

        $folder = $scriptDir
        $include = '*.nuspec;*.ps*1'
        # In case the script is in the same folder as the files you are replacing add it to the exclude list
        $exclude = "$($MyInvocation.MyCommand.Name);"
        $replacements = @{
            "$oldversion"="$newversion"
        }
        Replace-TextInFolder -folder $folder -include $include -exclude $exclude -replacements $replacements | Write-Verbose
        'Replacement complete' | Write-Verbose
    }
}

function LoadPester{
    [cmdletbinding()]
    param(
        $pesterDir = (Join-Path $scriptDir 'OutputRoot\contrib\pester\'),
        $pesterVersion = '3.3.11'
    )
    process{
        $pesterModulepath = (Join-Path $pesterDir ('Pester.{0}\tools\Pester.psd1' -f $pesterVersion))
        if(!(Test-Path $pesterModulepath)){
            if(!(Test-Path $pesterDir)){
                New-Item -Path $pesterDir -ItemType Directory
            }

            $pesterDir = (resolve-path $pesterDir)

            Push-Location
            try{
                cd $pesterDir
                &(Get-Nuget) install pester -version $pesterVersion -source https://www.nuget.org/api/v2/
            }
            finally{
                Pop-Location
            }
        }
        else{
            'Skipping pester download because it was found at [{0}]' -f $pesterModulepath | Write-Verbose
        }

        if(!(Test-Path $pesterModulepath)){
            throw ('Pester not found at [{0}]' -f $pesterModulepath)
        }

        Import-Module $pesterModulepath -Force
    }
}

function Run-Tests{
    [cmdletbinding()]
    param(
        $testDirectory = (join-path $scriptDir tests)
    )
    begin{ 
        LoadPester
    }
    process{
        # go to the tests directory and run pester
        push-location
        set-location $testDirectory

        $pesterArgs = @{}
        if($env:ExitOnPesterFail -eq $true){
            $pesterArgs.Add('-EnableExit',$true)
        }
        if($env:PesterEnableCodeCoverage -eq $true){
            $pesterArgs.Add('-CodeCoverage',@('..\publish-module.psm1','..\samples\default-publish.ps1'))
        }

        Invoke-Pester @pesterArgs
        pop-location
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

if(!$getversion -and !$newversion -and !$createnugetlocalrepo -and !$clean){
    # build is the default option
    $build = $true
}

if($build){ Build }
elseif($getversion){ GetExistingVersion }
elseif($newversion){ Set-Version -newversion $newversion }
elseif($createnugetlocalrepo){ CreateLocalNuGetRepo }
elseif($clean){ Clean }
else{
    $cmds = @('-build','-setversion','-createnugetlocalrepo','-clean')
    'No command specified, please pass in one of the following [{0}]' -f ($cmds -join ' ') | Write-Error
}

