[cmdletbinding(SupportsShouldProcess=$true)]
param($publishProperties, $packOutput)

$defaultPublishSettings = New-Object psobject -Property @{
    LocalInstallDir = ("${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\Web Tools\Publish\")
}

function Enable-PsNuGet{
    [cmdletbinding()]
    param($toolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\psnuget\",
        $psNuGetDownloadUrl = 'https://raw.githubusercontent.com/sayedihashimi/publish-module/master/ps-nuget.psm1')
    process{
        # try to local from local install first
        if(!(get-module 'ps-nuget')){
            $localpsnugetpath = Join-Path $defaultPublishSettings.LocalInstallDir 'ps-nuget.psm1'
            if(Test-Path $localpsnugetpath){
                'importing module [psnuget="{0}"] from local install dir' -f $localpsnugetpath | Write-Output
                Import-Module $localpsnugetpath -DisableNameChecking -Force -Scope Global
            }
        }

        if(!(get-module 'ps-nuget')){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory }

            $expectedPath = (Join-Path ($toolsDir) 'ps-nuget.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $psNuGetDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($psNuGetDownloadUrl, $expectedPath)
            }
        
            if(!$expectedPath){throw ('Unable to download ps-nuget.psm1')}

            'importing module [{0}]' -f $expectedPath | Write-Output
            Import-Module $expectedPath -DisableNameChecking -Force -Scope Global
        }
    }
}

function Enable-NuGetModule{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        $moduleFileName,
        [Parameter(Mandatory=$true,Position=1)] # later we can make this optional
        $version,
        [Parameter(Position=2)]
        $toolsDir = $global:PSNuGetSettings.DefaultToolsDir
    )
    process{
        if(!$moduleFileName){$moduleFileName = $name}

        if(!(get-module $name)){
            $localmodpath = Join-Path $defaultPublishSettings.LocalInstallDir ('{0}.{1}\tools\{2}.psm1' -f $name,$version,$moduleFileName)
            if(Test-Path $localmodpath){
                'importing module [{0}={1}] from local install dir' -f $name, $localmodpath | Write-Output
                Import-Module $localmodpath -DisableNameChecking -Force -Scope Global
            }
        }

        if(!(get-module $name)){
            $installDir = Get-PsNuGetPackage -name $name -version $version
            
            $moduleFile = (join-path $installDir ("tools\{0}.psm1" -f $moduleFileName))
            'Loading module from [{0}]' -f $moduleFile | Write-Output
            Import-Module $moduleFile -DisableNameChecking
        }
        else{
            'module [{0}] is already loaded skipping' -f $name | Write-Verbose
        }
    }
}

Enable-PsNuGet
Enable-NuGetModule -name 'publish-module' -version '0.0.8-beta'

$whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))

'Calling Publish-AspNet' | Write-Output
# call Publish-AspNet to perform the publish operation
Publish-AspNet -publishProperties $publishProperties -packOutput $packOutput -Verbose -WhatIf:$whatifpassed
