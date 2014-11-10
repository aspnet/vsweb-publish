[cmdletbinding()]
param()

$global:PSNuGetSettings = New-Object PSObject -Property @{
    DefaultToolsDir = "$env:LOCALAPPDATA\LigerShark\psnuget\"
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
        $toolsDir = ("$env:LOCALAPPDATA\LigerShark\tools\"),
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

        $expectedNuGetPkgFolder = ((Get-Item -Path ("$toolsDir\{0}.{1}" -f $name, $version) -ErrorAction SilentlyContinue))

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
function Ensure-PsNuGetPackageIsAvailable{
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
            $cmdArgs = @('install',$name,'-Version',$version,'-prerelease','-OutputDirectory',(Resolve-Path $toolsDir).ToString())
            $nugetPath = (Get-Nuget -toolsDir $toolsDir)

            'Calling nuget to install a package with the following args. [{0} {1}]' -f $nugetPath, ($cmdArgs -join ' ') | Write-Verbose
            &$nugetPath $cmdArgs | Out-Null

            $installPath = (Get-PsNuGetInstallPath -name $name -version $version -toolsDir $toolsDir)
        }

        # it should be set by now so throw if not
        if(!$installPath){
            throw ('Unable to restore nuget package. [name={0},version={1},toolsDir={2}]' -f $name, $version, $toolsDir)
        }

        $installPath
    }
}

Export-ModuleMember -function *
