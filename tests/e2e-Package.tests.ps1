[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
$moduleName = 'publish-module'
$modulePath = (Join-Path $scriptDir ('..\{0}.psm1' -f $moduleName))
$samplesdir = (Join-Path $scriptDir 'SampleFiles')

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
    process{
        $appObj = new-object -com shell.application
        $zip = $appObj.NameSpace($file)
        foreach($item in $zip.items()) {
            $appObj.Namespace($destination).copyhere($item)
        }
    }
}

Describe 'Package e2e publish tests' {
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
        $filesafter.length | Should Be $numPublishFiles
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
}

