[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")

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

$outputRoot = Join-Path $scriptDir "OutputRoot"
$nuspecFile = (get-item(Join-Path $scriptDir "publish-module.nuspec")).FullName
$nugetDevRepo = 'C:\temp\nuget\localrepo\'

if(!(Test-Path $outputRoot)){
    New-Item $outputRoot -ItemType Directory
}

$outputRoot = (Get-Item $outputRoot).FullName
# call nuget to create the package

$nugetArgs = @('pack',$nuspecFile,'-o',$outputRoot)
'Calling nuget.exe with the command:[nuget.exe {0}]' -f  ($nugetArgs -join ' ') | Write-Verbose
&(Get-Nuget) $nugetArgs

if(Test-Path $nugetDevRepo){
    Get-ChildItem -Path $outputRoot 'publish-module*.nupkg' | Copy-Item -Destination $nugetDevRepo
}