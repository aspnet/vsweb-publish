[cmdletbinding(SupportsShouldProcess=$true)]
param($PublishProperties, $OutputPath)

function Ensure-PsNuGetLoaded{
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

function Ensure-NuGetModuleIsLoaded{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        [Parameter(Mandatory=$true,Position=1)] # later we can make this optional
        $version,
        [Parameter(Position=2)]
        $toolsDir = $global:PSNuGetSettings.DefaultToolsDir
    )
    process{
        if(!(get-module $name)){
            $installDir = Ensure-PsNuGetPackageIsAvailable -name $name -version $version
            $moduleFile = (join-path $installDir ("tools\{0}.psm1" -f $name))
            'Loading module from [{0}]' -f $moduleFile | Write-Output
            Import-Module $moduleFile -DisableNameChecking
        }
        else{
            'module [{0}] is already loaded skipping' -f $name | Write-Output
        }
    }
}

Ensure-PsNuGetLoaded
Ensure-NuGetModuleIsLoaded -name 'publish-module' -version '0.0.6-beta'

$whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))

'Calling AspNet-Publish' | Write-Output
# call AspNet-Publish to perform the publish operation
AspNet-Publish -publishProperties $PublishProperties -OutputPath $OutputPath -Verbose -WhatIf:$whatifpassed
