[cmdletbinding(SupportsShouldProcess=$true)]
param($PublishProperties, $OutputPath)

function Enable-PsNuGet{
    [cmdletbinding()]
    param($toolsDir = "$env:LOCALAPPDATA\LigerShark\psnuget\",
        $psNuGetDownloadUrl = 'https://raw.githubusercontent.com/sayedihashimi/publish-module/master/ps-nuget.psm1')
    process{
        if(!(get-module 'ps-nuget')){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory }

            $expectedPath = (Join-Path ($toolsDir) 'ps-nuget.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $psNuGetDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($psNuGetDownloadUrl, $expectedPath)
            }
        
            if(!$expectedPath){throw ('Unable to download ps-nuget.psm1')}

            'importing module into global [{0}]' -f $expectedPath | Write-Output
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
        if(!(get-module $name)){
            $installDir = Get-PsNuGetPackage -name $name -version $version
            if(!$moduleFileName){$moduleFileName = $name}
            $moduleFile = (join-path $installDir ("tools\{0}.psm1" -f $moduleFileName))
            'Loading module from [{0}]' -f $moduleFile | Write-Output
            Import-Module $moduleFile -DisableNameChecking
        }
        else{
            'module [{0}] is already loaded skipping' -f $name | Write-Output
        }
    }
}

Enable-PsNuGet
Enable-NuGetModule -name 'publish-module' -version '0.0.7-beta'

$whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))

'Calling Publish-AspNet' | Write-Output
# call Publish-AspNet to perform the publish operation
Publish-AspNet -publishProperties $PublishProperties -OutputPath $OutputPath -Verbose -WhatIf:$whatifpassed
