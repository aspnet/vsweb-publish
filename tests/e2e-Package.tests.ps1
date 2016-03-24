[cmdletbinding()]
param(
    $useCustomMSDeploy
)

if($env:e2ePkgTestUseCustomMSDeploy){
    $useCustomMSDeploy = $true
}

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
$moduleName = 'publish-module'
$modulePath = (Join-Path $scriptDir ('..\{0}.psm1' -f $moduleName))
$samplesdir = (Join-Path $scriptDir 'SampleFiles')
$msdeployDownloadUrl = 'https://sayed02.blob.core.windows.net/download/msdeploy-v3-01-.zip'

if(Test-Path $modulePath){
    "Importing module from [{0}]" -f $modulePath | Write-Verbose

    if((Get-Module $moduleName)){ Remove-Module $moduleName -Force }
    
    Import-Module $modulePath -PassThru -DisableNameChecking | Out-Null
}
else{
    throw ('Unable to find module at [{0}]' -f $modulePath )
}

function Extract-ZipFile {
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        $file, 
        [Parameter(Position=1,Mandatory=$true)]
        $destination
    )
    begin{
        [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
    }
    process{
        'Extracting zip file [{0}] to {1}' -f $file,$destination | Write-Verbose
        if(!(Test-Path $destination)){
            New-Item -ItemType Directory -Path $destination | Out-Null
        }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($file,$destination) | Out-Null
    }
}

Describe 'Package e2e publish tests' {
    if($useCustomMSDeploy){
        # download the .zip file and extract it
        $downloadDest = (Join-Path $TestDrive 'msdeploy.zip')
        (New-Object System.Net.WebClient).DownloadFile($msdeployDownloadUrl, $downloadDest)
        if(!(Test-Path $downloadDest)){
            throw ('Unable to download msdeploy to [{0}]' -f $downloadDest)
        }
        $msdExtractFolder = (New-Item -ItemType Directory -Path (join-path $TestDrive 'MSDeployBin')).FullName
        Unblock-File $downloadDest
        Extract-ZipFile -file $downloadDest -destination $msdExtractFolder
        $msdeployExePath = (Join-Path $msdExtractFolder 'msdeploy.exe')
        if(!(Test-Path $msdeployExePath)){
            throw ('could not find msdeploy.exe at [{0}]' -f $msdeployExePath)
        }

        'Updating msdeploy.exe to point to [{0}]' -f $msdeployExePath | Write-Verbose
        $env:msdeployinstallpath = $msdExtractFolder
    }

    [string]$mvcSourceFolder = (resolve-path (Join-Path $samplesdir 'MvcApplication'))
    [string]$mvcPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))
    [int]$numPublishFiles = ((Get-ChildItem $mvcPackDir -Recurse) | Where-Object { !$_.PSIsContainer }).Length

    It 'Can publish to a package' {
        # publish the pack output to a new temp folder
        $pubishDir = (New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2ePackage\Basic01\'))
        $publishDest = (Join-Path $pubishDir 'pkg.zip')
        
        Test-Path $publishDest | Should be False

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'="$publishDest"
        }
        Test-Path $publishDest | Should be True

        $extractDir = (New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2ePackage\Basic01-CopiedFiles\'))
        Extract-ZipFile -file $publishDest -destination ($extractDir.FullName)
        # check to see that the files exist
        $filesafter = (Get-ChildItem $extractDir -Recurse) | Where-Object { !$_.PSIsContainer }
        $filesafter.length - 2 | Should Be $numPublishFiles
    }

    It 'The result is in package under website folder' {
        # publish the pack output to a new temp folder
        $pubishDir = (New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2ePackage\Basic02\'))
        $publishDest = (Join-Path $pubishDir 'pkg.zip')

        Test-Path $publishDest | Should be False

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'="$publishDest"
        }

        Test-Path $publishDest | Should be True

        $extractDir = (New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2ePackage\Basic02-CopiedFiles\'))
        Extract-ZipFile -file $publishDest -destination ($extractDir.FullName)
        Test-Path (Join-Path $extractDir Content) | Should Be $true
    }

    <#
    It 'Can publish to a relative path for' {
    }
    #>

    # reset this back to the default
    $env:msdeployinstallpath = $null
}

