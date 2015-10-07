# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

<#
    Add the following snippet to your .ps1 file to ensure that the publish-module is loaded and ready for use
#>

function Ensure-PublishModuleLoaded{
    [cmdletbinding()]
    param($versionToInstall = '1.0.2-beta2',
        $installScriptUrl = 'http://go.microsoft.com/fwlink/?LinkId=524326', # GetPublishModule.ps1
        $toolsDir = ("$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\tools\"),
        $installScriptPath = (Join-Path $toolsDir 'GetPublishModule.ps1'))
    process{
        if(!(Test-Path $installScriptPath)){
            if(!(Test-Path $toolsDir)){
                New-Item -Path $toolsDir -ItemType Directory | Out-Null
            }

            'Downloading from [{0}] to [{1}]' -f $installScriptUrl, $installScriptPath| Write-Verbose
            (new-object Net.WebClient).DownloadFile($installScriptUrl,$installScriptPath) | Out-Null
        }
        $installScriptArgs = @($versionToInstall,$toolsDir)
        # seems to be the best way to invoke a .ps1 file with parameters
        Invoke-Expression "& `"$installScriptPath`" $installScriptArgs"
    }
}

Ensure-PublishModuleLoaded
