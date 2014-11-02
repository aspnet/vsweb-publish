<#
    Add the following snippet to your .ps1 file to ensure that the publish-module is loaded and ready for use
#>

function Ensure-PublishModuleLoaded{
    [cmdletbinding()]
    param($versionToInstall = '0.0.3-beta',
        $installScriptUrl = 'https://raw.githubusercontent.com/sayedihashimi/publish-module/master/GetPublishModule.ps1',
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
        $installScriptPath = (Join-Path $toolsDir 'GetPublishModule.ps1'))
    process{
        if(!(Test-Path $installScriptPath)){
            if(!(Test-Path $toolsDir)){
                New-Item -Path $toolsDir -ItemType Directory | Out-Null
            }

            'Downloading from [{0}] to [{1}]' -f $installScriptUrl, $installScriptPath| Write-Verbose
            (new-object Net.WebClient).DownloadFile($installScriptUrl,$installScriptPath) | Out-Null
        }
        $installargs = @("$versionToInstall","$toolsDir")
        &($installScriptPath) $installargs
    }
}

Ensure-PublishModuleLoaded
