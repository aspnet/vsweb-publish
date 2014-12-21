[cmdletbinding()]
param()

$global:PSNuGetSettings = New-Object PSObject -Property @{
    DefaultToolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\psnuget\"
    NuGetDownloadUrl = 'http://nuget.org/nuget.exe'
}
<#
.SYNOPSIS
    This will return nuget from the $toolsDir. If it is not there then it
    will automatically be downloaded before the call completes.
#>
function Get-Nuget(){
    [cmdletbinding()]
    param(
        $toolsDir = ("$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\tools\"),
        $nugetDownloadUrl = $global:PSNuGetSettings.NuGetDownloadUrl
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

<#
.SYNOPSIS
    This will return the path to where the given NuGet package is installed
    under %localappdata%. If the package is not found then empty/null is returned.
#>
function Get-PsNuGetInstallPath{
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
        $pathToFoundPkgFolder = $null
		$toolsDir=(([uri]($toolsDir)).AbsolutePath)
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
function Get-PsNuGetPackage{
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
        if(!(Test-Path $toolsDir)){
            New-Item -Path $toolsDir -ItemType Directory | out-null 
        }
        # if it's already installed just return the path
        $installPath = (Get-PsNuGetInstallPath -name $name -version $version -toolsDir $toolsDir)
        if(!$installPath){
            # install the nuget package and then return the path
            $outdir = ([uri]('{0}' -f (Resolve-Path $toolsDir).ToString())).AbsolutePath

            $cmdArgs = @('install',$name,'-Version',$version,'-prerelease','-OutputDirectory',$outdir)
            $nugetPath = (Get-Nuget -toolsDir $outdir)
            set-alias nugettemp $nugetPath | Out-Null
            'Calling nuget to install a package with the following args. [{0} {1}]' -f $nugetPath, ($cmdArgs -join ' ') | Write-Verbose
            nugettemp $cmdArgs | Out-Null

            $installPath = (Get-PsNuGetInstallPath -name $name -version $version -toolsDir $toolsDir)
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
Get-PsNuGetPackage.

This function assumes that the name of the PS module is the name of the .psm1 file 
and that file is in the tools\ folder in the NuGet package.

.EXAMPLE
Enable-NuGetModule -name 'publish-module' -version '0.0.14-beta'

.EXAMPLE
Enable-NuGetModule -name 'publish-module-blob' -version '0.0.14-beta'
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
        $toolsDir = $global:PSNuGetSettings.DefaultToolsDir
    )
    process{
        if(!(get-module $name)){
            $installDir = Get-PsNuGetPackage -name $name -version $version
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

function Get-LatestVersionForPsNuGetPackage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        [switch]$prerelease,
        [Parameter(Position=1)]
        $toolsDir = $global:PSNuGetSettings.DefaultToolsDir
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
