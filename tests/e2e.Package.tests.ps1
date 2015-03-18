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

Describe 'Package e2e publish tests' {
    [string]$mvcSourceFolder = (resolve-path (Join-Path $samplesdir 'MvcApplication'))
    [string]$mvcPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))
    [int]$numPublishFiles = ((Get-ChildItem $mvcPackDir -Recurse) | Where-Object { !$_.PSIsContainer }).Length

    It 'Package publish 1' {
        $publishDest = (Join-Path $TestDrive 'e2ePackage\Basic01\webpkg.zip')

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'="$publishDest"
        }
        $publishDest | Should Exist
    }
    
    It 'Can publish with a relative path for DesktopBuildPackageLocation' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive "e2ePackage\relpath\result.zip")
        
        Push-Location
        mkdir $publishDest
        Set-Location $publishDest

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'='.\webpkg.zip'
        }
        
        Pop-Location

        "$publishDest\webpkg.zip" | Should Exist
    }

    It 'throws when DesktopBuildPackageLocation is missing'{
        {Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
        }} | Should Throw
    }

    It 'Can package to a path with a space' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive 'e2ePackage\PublishUrl WithSpace\webpkg.zip')
        
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'="$publishDest"
        }
        
        $publishDest | Should Exist        
    }

    It 'Can exclude files when a single file is passed in' {
        $publishDest = (Join-Path $TestDrive 'e2ePackage\exclude01\pkg.zip')
        
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'="$publishDest"
            'ExcludeFiles'=@(
		            @{'absolutepath'='approot\\src\\MvcApplication\\Views\\Home'}
            )
        }
        
        # todo: check to see that the file was skipped
    }

    It 'Can exclude files when a multiple files are passed in' {
        $publishDest = (Join-Path $TestDrive 'e2ePackage\exclude02\pkg.zip')

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'="$publishDest"
            'ExcludeFiles'=@(
		            @{'absolutepath'='approot\\src\\MvcApplication\\Views\\Home'},
		            @{'absolutepath'='wwwroot\\web.config'}
            )
        }
        
        # todo: check to see that the files were skipped
    }

    It 'Performs replacements when one replacement is passed' {
        $publishDest = (Join-Path $TestDrive 'e2ePackage\replace01\pkg.zip')

        $textToReplace = 'Random'
        $textReplacemnet = 'Replaced'

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'="$publishDest"
            'Replacements' = @(
		        @{'file'='tobereplaced.txt$';'match'="$textToReplace";'newValue'="$textReplacemnet"})
        } 

        $publishDest | Should Exist
        # todo: check that the text was replaced see file system tests
    }

    It 'Performs replacements when more than one replacement is passed' {
        $publishDest = (Join-Path $TestDrive 'e2ePackage\replace02\pkg.zip')

        $textToReplaceTextFile = 'Random'
        $textReplacemnetTextFile = 'Replaced'
        $textToReplaceWebConfig = '1.0.0-beta1'
        $textReplacemnetWebConfig = '1.0.0-custom1'

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='Package'
            'DesktopBuildPackageLocation'="$publishDest"
            'Replacements' = @(
		        @{'file'='tobereplaced.txt$';'match'="$textToReplaceTextFile";'newValue'="$textReplacemnetTextFile"},
                @{'file'='web.config$';'match'="$textToReplaceWebConfig";'newValue'="$textReplacemnetWebConfig"})
        } 

        $publishDest | Should Exist
        # todo: check that the text was replaced see file system tests
    }
}