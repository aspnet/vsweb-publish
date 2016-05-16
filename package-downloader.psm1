# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

[cmdletbinding()]
param()

$global:PkgDownloaderSettings = New-Object PSObject -Property @{
    DefaultToolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\package-downloader\"
    NuGetDownloadUrl = 'http://nuget.org/nuget.exe'
}
<#
.SYNOPSIS
    This will return nuget from the $toolsDir. If it is not there then it
    will automatically be downloaded before the call completes.
#>
function Get-Nuget{
    [cmdletbinding()]
    param(
        $toolsDir = ("$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\tools\"),
        $nugetDownloadUrl = $global:PkgDownloaderSettings.NuGetDownloadUrl
    )
    process{
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null 
        }

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

function Execute-CommandString{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [string[]]$command,

        [switch]
        $ignoreExitCode
    )
    process{
        foreach($cmdToExec in $command){
            'Executing command [{0}]' -f $cmdToExec | Write-Verbose
            cmd.exe /D /C $cmdToExec

            if(-not $ignoreExitCode -and ($LASTEXITCODE -ne 0)){
                $msg = ('The command [{0}] exited with code [{1}]' -f $cmdToExec, $LASTEXITCODE)
                throw $msg
            }
        }
    }
}

<#
.SYNOPSIS
    This will return the path to where the given NuGet package is installed
    under %localappdata%. If the package is not found then empty/null is returned.
#>
function Get-PackageDownloaderInstallPath{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        [Parameter(Mandatory=$true,Position=1)] # later we can make this optional
        $version,
        [Parameter(Position=2)]
        $toolsDir = $global:PkgDownloaderSettings.DefaultToolsDir
    )
    process{
        $pathToFoundPkgFolder = $null
        $toolsDir=(get-item $toolsDir).FullName
		$expectedNuGetPkgFolder = ((Get-Item -Path (join-path $toolsDir (('{0}.{1}' -f $name, $version))) -ErrorAction SilentlyContinue))

        if($expectedNuGetPkgFolder){
            $pathToFoundPkgFolder = $expectedNuGetPkgFolder.FullName
        }

        $pathToFoundPkgFolder
    }
}

<#
.SYNOPSIS
    This will return the path to where the given NuGet package is installed.
#>
function Enable-PackageDownloader{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        [Parameter(Mandatory=$true,Position=1)] # later we can make this optional
        $version,
        [Parameter(Position=2)]
        $toolsDir = $global:PkgDownloaderSettings.DefaultToolsDir,

        [Parameter(Position=3)]
        [string]$nugetUrl = $null
    )
    process{
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null 
        }
        $toolsDir = (Get-Item $toolsDir).FullName.TrimEnd('\')
        # if it's already installed just return the path
        $installPath = (Get-PackageDownloaderInstallPath -name $name -version $version -toolsDir $toolsDir)
        if(!$installPath){
            # install the nuget package and then return the path
            $outdir = (get-item (Resolve-Path $toolsDir)).FullName.TrimEnd("\") # nuget.exe doesn't work well with trailing slash

            # set working directory to avoid needing to specify OutputDiretory, having issues with spaces
            Push-Location | Out-Null
            Set-Location $outdir | Out-Null
            $cmdArgs = @('install',$name,'-Version',$version,'-prerelease')
            
            if($nugetUrl -and !([string]::IsNullOrWhiteSpace($nugetUrl))){
                $cmdArgs += "-source"
                $cmdArgs += $nugetUrl
            }

            $nugetCommand = ('"{0}" {1}' -f (Get-Nuget -toolsDir $outdir), ($cmdArgs -join ' ' ))
            'Calling nuget to install a package with the following args. [{0}]' -f $nugetCommand | Write-Verbose
            Execute-CommandString -command $nugetCommand | Out-Null
            Pop-Location | Out-Null

            $installPath = (Get-PackageDownloaderInstallPath -name $name -version $version -toolsDir $toolsDir)
        }

        # it should be set by now so throw if not
        if(!$installPath){
            throw ('Unable to restore nuget package. [name={0},version={1},toolsDir={2}]' -f $name, $version, $toolsDir)
        }

        $installPath
    }
}

<#
This will ensure that the given module is imported into the PS session. If not then 
it will be imported from %localappdata%. The package will be restored using
Enable-PackageDownloader.

This function assumes that the name of the PS module is the name of the .psm1 file 
and that file is in the tools\ folder in the NuGet package.

.EXAMPLE
Enable-NuGetModule -name 'publish-module' -version '1.1.1'

.EXAMPLE
Enable-NuGetModule -name 'publish-module-blob' -version '1.1.1'
#>

# For now this function has to be declared directly in the publish
# .ps1 file, not sure why.
function Enable-NuGetModule{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        $moduleFileName,
        [Parameter(Mandatory=$true,Position=1)] # later we can make this optional
        $version,
        [Parameter(Position=2)]
        $toolsDir = $global:PkgDownloaderSettings.DefaultToolsDir,

        [Parameter(Position=3)]
        $nugetUrl = $null
    )
    process{
        if(!(get-module $name)){
            $installDir = Enable-PackageDownloader -name $name -version $version -nugetUrl $nugetUrl
            if(!$moduleFileName){$moduleFileName = $name}
            $moduleFile = (join-path $installDir ("tools\{0}.psm1" -f $moduleFileName))
            'Loading module from [{0}]' -f $moduleFile | Write-Verbose
            Import-Module $moduleFile -DisableNameChecking -Global -Force
        }
        else{
            'module [{0}] is already loaded skipping' -f $name | Write-Verbose
        }
    }
}

function Get-LatestVersionForPackageDownloader{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        [switch]$prerelease,
        [Parameter(Position=1)]
        $toolsDir = $global:PkgDownloaderSettings.DefaultToolsDir
    )
    process{
        $nugetArgs = @('list',$name)

        if($prerelease){
            $nugetArgs += '-prerelease'
        }

        'Getting pack versions for [{0}]' -f $name | Write-Verbose
        'Calling nuget with the following args [{0}]' -f ($nugetArgs -join ' ') | Write-Verbose

        &(Get-Nuget) $nugetArgs | where{$_.StartsWith('{0} ' -f $name)} |sort
    }
}

Export-ModuleMember -function *
