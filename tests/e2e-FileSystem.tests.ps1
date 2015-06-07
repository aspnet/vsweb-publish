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
    [int]$numPublishFiles = ((Get-ChildItem $mvcPackDir -Recurse) | Where-Object { !$_.PSIsContainer }).Length

    It 'Publish file system' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\Basic01')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue) | Where-Object { !$_.PSIsContainer }
        $filesbefore | Should BeNullOrEmpty

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
        }
        
        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse) | Where-Object { !$_.PSIsContainer }
        $filesafter.length | Should Be $numPublishFiles
    }

    It 'Can publish with a relative path for publishUrl' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\relpathPublishUrl')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue) | Where-Object { !$_.PSIsContainer }
        $filesbefore | Should BeNullOrEmpty

        Push-Location
        mkdir $publishDest
        Set-Location $publishDest

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'='.\'
        }
        
        Pop-Location

        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse) | Where-Object { !$_.PSIsContainer }
        $filesafter.length | Should Be $numPublishFiles
    }

    It 'Publish file system can publish to a dir with a space' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\PublishUrl WithSpace\')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -File -ErrorAction SilentlyContinue)
        $filesbefore.length | Should Be 0

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
        }
        
        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse -File)
        $filesafter.length | Should Be $numPublishFiles
    }

    It 'Can publish with a relative path for publishUrl' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\relpathPackOutput')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue) | Where-Object { !$_.PSIsContainer }
        $filesbefore | Should BeNullOrEmpty

        Push-Location
        Set-Location $mvcPackDir

        Publish-AspNet -packOutput .\ -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
        }
        
        Pop-Location

        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse) | Where-Object { !$_.PSIsContainer }
        $filesafter.length | Should Be $numPublishFiles
    }

    It 'Can exclude files when a single file is passed in' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\exclude01')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue) | Where-Object { !$_.PSIsContainer }
        $filesbefore | Should BeNullOrEmpty

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
            'ExcludeFiles'=@(
		            @{'absolutepath'='approot\\src\\MvcApplication\\Views\\Home'}
            )
        }
        
        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse) | Where-Object { !$_.PSIsContainer }
        $filesafter.length | Should Be ($numPublishFiles-1)
    }

    It 'Can exclude files when a multiple files are passed in' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\exclude02')
        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue)
        $filesbefore | Should BeNullOrEmpty

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
            'ExcludeFiles'=@(
		            @{'absolutepath'='approot\\src\\MvcApplication\\Views\\Home'},
		            @{'absolutepath'='wwwroot\\web.config'}
            )
        }
        
        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse) | Where-Object { !$_.PSIsContainer }
        $filesafter.length | Should Be ($numPublishFiles-2)
    }

    It 'Performs replacements when one replacement is passed' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\replace01')

        $textToReplace = 'Random'
        $textReplacemnet = 'Replaced'

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
            'Replacements' = @(
		        @{'file'='tobereplaced.txt$';'match'="$textToReplace";'newValue'="$textReplacemnet"})
        } 

        $filePathInPackDir = (resolve-path (Join-Path $mvcPackDir 'wwwroot\tobereplaced.txt'))
        $filePathInPackDir | Should Contain $textToReplace
        $filePathInPackDir | Should Not Contain $textReplacemnet

        $filePathInPublishDir = (resolve-path (Join-Path $publishDest 'wwwroot\tobereplaced.txt'))
        $filePathInPublishDir | Should Not Contain $textToReplace
        $filePathInPublishDir | Should Contain $textReplacemnet
    }

    It 'Performs replacements when more than one replacement is passed' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\replace02')

        $textToReplaceTextFile = 'Random'
        $textReplacemnetTextFile = 'Replaced'
        $textToReplaceWebConfig = '1.0.0-beta1'
        $textReplacemnetWebConfig = '1.0.0-custom1'

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishDest"
            'Replacements' = @(
		        @{'file'='tobereplaced.txt$';'match'="$textToReplaceTextFile";'newValue'="$textReplacemnetTextFile"},
                @{'file'='web.config$';'match'="$textToReplaceWebConfig";'newValue'="$textReplacemnetWebConfig"})
        } 

        $textFileInPackDir = (resolve-path (Join-Path $mvcPackDir 'wwwroot\tobereplaced.txt'))
        $textFileInPackDir | Should Contain $textToReplaceTextFile
        $textFileInPackDir | Should Not Contain $textReplacemnetTextFile

        $webConfigInPackDir = (resolve-path (Join-Path $mvcPackDir 'wwwroot\web.config'))
        $webConfigInPackDir | Should Contain $textToReplaceWebConfig
        $webConfigInPackDir | Should Not Contain $textReplacemnetWebConfig


        $textFileInPublishDir = (resolve-path (Join-Path $publishDest 'wwwroot\tobereplaced.txt'))
        $textFileInPublishDir | Should Not Contain $textToReplaceTextFile
        $textFileInPublishDir | Should Contain $textReplacemnetTextFile

        $webConfigInPublishDir = (resolve-path (Join-Path $publishDest 'wwwroot\web.config'))
        $webConfigInPublishDir | Should Not Contain $textToReplaceWebConfig
        $webConfigInPublishDir | Should Contain $textReplacemnetWebConfig
    }

    It 'throws if publishUrl is empty' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\THrowIfPublishUrlEmpty')

        {Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
        }} | Should throw
    }
    $script:samplepubxmlfilesys01 = @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <WebPublishMethod>FileSystem</WebPublishMethod>
    <WebRoot>wwwroot</WebRoot>
    <publishUrl>{0}</publishUrl>
    <DeleteExistingFiles>False</DeleteExistingFiles>
  </PropertyGroup>
</Project>
'@
    It 'Publish file system using .pubxml' {
        # publish the pack output to a new temp folder
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\Pubfilesyspubxml')
        $contents = ($script:samplepubxmlfilesys01 -f $publishDest)
        $samplePath = 'get-propsfrompubxml\sample02.pubxml'
        Setup -File -Path $samplePath -Content $contents
        $pubxmlpath = Join-Path $TestDrive $samplePath

        # verify the folder is empty
        $filesbefore = (Get-ChildItem $publishDest -Recurse -ErrorAction SilentlyContinue) | Where-Object { !$_.PSIsContainer }
        $filesbefore | Should BeNullOrEmpty

        Publish-AspNet -packOutput $mvcPackDir -pubProfilePath $pubxmlpath

        # check to see that the files exist
        $filesafter = (Get-ChildItem $publishDest -Recurse) | Where-Object { !$_.PSIsContainer }
        $filesafter.length | Should Be $numPublishFiles
    }
}

