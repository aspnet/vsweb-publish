# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
$moduleName = 'publish-module'
$samplesdir = (Join-Path $scriptDir 'SampleFiles')
$nugetPrivateFeedUrl = ($env:NuGetPrivateFeedUrl)

Describe 'Default publish tests' {
    [string]$mvcSourceFolder = (resolve-path (Join-Path $samplesdir 'MvcApplication'))
    [string]$mvcPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))
    [int]$numPublishFiles = ((Get-ChildItem $mvcPackDir -Recurse) | Where-Object { !$_.PSIsContainer }).Length

    BeforeEach {
        if(Get-Module publish-module){
            Remove-Module publish-module -Force
        }
    }

    It 'Publish to file system with default publish' {
        if(!([string]::IsNullOrWhiteSpace($nugetPrivateFeedUrl))){
            # publish the pack output to a new temp folder
            $publishDest = (Join-Path $TestDrive 'e2eDefaultPub\Basic01')
            # verify the folder is empty
            $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue) | Where-Object { !$_.PSIsContainer }
            $filesbefore | Should BeNullOrEmpty

            $defPubFile = (resolve-path (Join-Path $scriptDir '..\samples\default-publish.ps1') )
            $defPubFile | Should Exist

            & ($defPubFile) -nugetUrl $nugetPrivateFeedUrl -packOutput $mvcPackDir -publishProperties @{
                'WebPublishMethod'='FileSystem'
                'publishUrl'="$publishDest"
            }
        
            # check to see that the files exist
            $filesafter = (Get-ChildItem $publishDest -Recurse) | Where-Object { !$_.PSIsContainer }
            $filesafter.length | Should Be $numPublishFiles    
        }
        else{
            'Skipping becuase $env:NuGetPrivateFeedUrl is empty' | Write-Host
            1 | Should be 1
        }
    }
}