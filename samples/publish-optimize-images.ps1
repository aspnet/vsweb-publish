[cmdletbinding(SupportsShouldProcess=$true)]
param($PublishProperties, $OutputPath)

function Ensure-PublishModuleLoaded{
    [cmdletbinding()]
    param($versionToInstall = '0.0.5-beta',
        $installScriptUrl = 'https://raw.githubusercontent.com/sayedihashimi/publish-module/master/GetPublishModule.ps1',
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
        $installScriptPath = (Join-Path $toolsDir 'GetPublishModule.ps1'))
    process{
        if(!(Test-Path $installScriptPath)){
            $installDir = [System.IO.Path]::GetDirectoryName($installScriptPath)
            if(!(Test-Path $installDir)){
                New-Item -Path $installDir -ItemType Directory -WhatIf:$false | Out-Null
            }

            'Downloading from [{0}] to [{1}]' -f $installScriptUrl, $installScriptPath| Write-Verbose
            (new-object Net.WebClient).DownloadFile($installScriptUrl,$installScriptPath) | Out-Null       
        }
	
		$installScriptArgs = @($versionToInstall,$toolsDir)
        # seems to be the best way to invoke a .ps1 file with parameters
        Invoke-Expression "& `"$installScriptPath`" $installScriptArgs"
    }
}

function OptimizeImages{
    [cmdletbinding()]
    param(
        $folder,
        $force = $false,
        $customTemp = "$env:LocalAppData\CustomPublish\",
        $imgOptUrl = 'https://raw.githubusercontent.com/ligershark/AzureJobs/master/ImageCompressor.Job/optimize-images.ps1'
        )
    process{
        if(!(Test-Path $customTemp)){New-Item $customTemp -ItemType Directory}
        
        $imgOptPath = (Join-Path $customTemp 'optimize-images.ps1')
        if(!(Test-Path $imgOptPath)){
            # download the file
            'Downloading optimize-images.ps1' | Write-Verbose
            (New-Object System.Net.WebClient).DownloadFile($imgOptUrl, $imgOptPath)
        }

        &$imgOptPath $folder $force
    }
}

$whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))
'loading publish-module' | Write-Output
Ensure-PublishModuleLoaded

$customTemp = "$env:LocalAppData\CustomPublish\"
$imgOptPath = Join-Path $customTemp 'optimize-images.ps1'
$imgOptUrl = 'https://raw.githubusercontent.com/ligershark/AzureJobs/master/ImageCompressor.Job/optimize-images.ps1'

$webrootOutputFolder = (get-item (Join-Path $OutputPath 'wwwroot')).FullName

OptimizeImages -folder $webrootOutputFolder $true

'Calling AspNet-Publish' | Write-Output
# call AspNet-Publish to perform the publish operation
AspNet-Publish -publishProperties $PublishProperties -OutputPath $OutputPath -Verbose -WhatIf:$whatifpassed