[cmdletbinding(SupportsShouldProcess=$true)]
param($publishProperties, $packOutput)

function Get-VisualStudio2015InstallPath{
    [cmdletbinding()]
    param()
    process{
        $keysToCheck = @('hklm:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\14.0','hklm:\SOFTWARE\Microsoft\VisualStudio\14.0')
        [string]$vsInstallPath=$null

        foreach($keyToCheck in $keysToCheck){
            if(Test-Path $keyToCheck){
                $vsInstallPath = (Get-itemproperty $keyToCheck -Name InstallDir | select -ExpandProperty InstallDir)
            }

            if($vsInstallPath){
                break;
            }
        }

        $vsInstallPath
    }
}

$defaultPublishSettings = New-Object psobject -Property @{
    LocalInstallDir = ("{0}Extensions\Microsoft\Web Tools\Publish\" -f (Get-VisualStudio2015InstallPath))
}

function Enable-PsNuGet{
    [cmdletbinding()]
    param($toolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\psnuget\",
        $psNuGetDownloadUrl = 'https://raw.githubusercontent.com/sayedihashimi/publish-module/master/getnuget.psm1')
    process{
		if(get-module getnuget){
			# TODO: we should check the version loaded and skip removing if the correct version is already loaded.
			remove-module getnuget | Out-Null
		}

        # try to local from local install first
        if(!(get-module 'getnuget')){
            $localpsnugetpath = Join-Path $defaultPublishSettings.LocalInstallDir 'getnuget.psm1'
            if(Test-Path $localpsnugetpath){
                'importing module [psnuget="{0}"] from local install dir' -f $localpsnugetpath | Write-Output
                Import-Module $localpsnugetpath -DisableNameChecking -Force -Scope Global
            }
        }

        if(!(get-module 'getnuget')){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory -WhatIf:$false }

            $expectedPath = (Join-Path ($toolsDir) 'getnuget.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $psNuGetDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($psNuGetDownloadUrl, $expectedPath)
            }
        
            if(!$expectedPath){throw ('Unable to download getnuget.psm1')}

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
			# TODO: we should check the version loaded and skip removing if the correct version is already loaded.
			remove-module $name | Out-Null
		}

        if(!(get-module $name)){
            $localmodpath = Join-Path $defaultPublishSettings.LocalInstallDir ('{0}.{1}\tools\{2}.psm1' -f $name,$version,$moduleFileName)

            if(Test-Path $localmodpath){
                'importing module [{0}={1}] from local install dir' -f $name, $localmodpath | Write-Verbose
                Import-Module $localmodpath -DisableNameChecking -Force -Scope Global
            }

        }

        if(!(get-module $name)){
            $installDir = Get-PsNuGetPackage -name $name -version $version
            $moduleFile = (join-path $installDir ("tools\{0}.psm1" -f $moduleFileName))
            Import-Module $moduleFile -DisableNameChecking
        }
        else{
            'module [{0}] is already loaded skipping' -f $name | Write-Verbose
        }
    }
}

try{
	Enable-PsNuGet
	Enable-NuGetModule -name 'publish-module' -version '0.0.16-beta'

	$whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))

	'Calling Publish-AspNet' | Write-Output
	# call Publish-AspNet to perform the publish operation
	Publish-AspNet -publishProperties $publishProperties -packOutput $packOutput -Verbose -WhatIf:$whatifpassed
}
catch{
	"An error occured during publish.`n{0}" -f $_.Exception.Message | Write-Error
}