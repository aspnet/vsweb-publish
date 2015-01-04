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

Describe 'FileSystem e2e publish tests' {
    [string]$mvcSourceFolder = (resolve-path (Join-Path $samplesdir 'MvcApplication'))
    [string]$mvcPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))

    It 'Publish file system' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\Basic01')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue)
        $filesbefore.length | Should Be 0

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
        }
        
        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse)
        $filesafter.length | Should Be 29
    }

    It 'Can exclude files when a single file is passed in' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\exclude01')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue)
        $filesbefore.length | Should Be 0

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
            'ExcludeFiles'=@(
		            @{'absolutepath'='approot\\src\\MvcApplication\\Views\\Home'}
            )
        }
        
        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse)
        $filesafter.length | Should Be 28
    }

    It 'Can exclude files when a multiple files are passed in' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\exclude02')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue)
        $filesbefore.length | Should Be 0

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
            'ExcludeFiles'=@(
		            @{'absolutepath'='approot\\src\\MvcApplication\\Views\\Home'},
		            @{'absolutepath'='wwwroot\\web.config'}
            )
        }
        
        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse)
        $filesafter.length | Should Be 27
    }
}












