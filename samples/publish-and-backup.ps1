[cmdletbinding(SupportsShouldProcess=$true)]
param($publishProperties, $packOutput)

function Ensure-PublishModuleLoaded{
    [cmdletbinding()]
    param($versionToInstall = '1.0.0-pre',
        $installScriptUrl = 'http://go.microsoft.com/fwlink/?LinkId=524326', # GetPublishModule.ps1
        $toolsDir = ("$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\tools\"),
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

$whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))
'loading publish-module' | Write-Output
Ensure-PublishModuleLoaded

$webrootOutputFolder = (get-item (Join-Path $packOutput 'wwwroot')).FullName

'Calling Publish-AspNet' | Write-Output
# call Publish-AspNet to perform the publish operation
Publish-AspNet -publishProperties $publishProperties -packOutput $packOutput -Verbose -WhatIf:$whatifpassed

$backupdir = 'C:\temp\publish\new'
if(Test-Path){ Remove-Item $backupdir -Recurse -Force }
if(!(Test-path)){
	New-Item $backupdir -ItemType Directory
}

# publish with file system
Publish-AspNet -publishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'='C:\temp\publish\new'} -packOutput $backupdir -Verbose -WhatIf:$whatifpassed
