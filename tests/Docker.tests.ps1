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

Describe 'Docker publish unit tests' {
    Mock Publish-DockerContainerApp {
        return {
            $command
        }
    } -ModuleName 'publish-module'
    
    $dockerPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))
    $tokenReplacedDockerfilePath = (resolve-path (Join-Path $samplesdir 'Dockerfile - TokenReplaced'))
    $targetDockerfile = (Join-Path $dockerPackDir 'Dockerfile')
    $targetDockerfile2 = (Join-Path $dockerPackDir 'approot\src\MvcApplication\Dockerfile')
    
    BeforeEach {
        # Clean up Dockerfiles from last test
        if (Test-Path $targetDockerfile) {
            Remove-Item $targetDockerfile
        }
        if (Test-Path $targetDockerfile2) {
            Remove-Item $targetDockerfile2
        }
    }
    
    AfterEach {
        # Clean up Dockerfile from last test
        if (Test-Path $targetDockerfile) {
            Remove-Item $targetDockerfile
        }
        if (Test-Path $targetDockerfile2) {
            Remove-Item $targetDockerfile2
        }
    }

    It 'Verify the correct default Dockerfile is located and tokens are replaced correctly' {

        Publish-AspNet -packOutput $dockerPackDir -publishProperties @{
            'WebPublishMethod'='Docker'
            "DockerBaseImageName"="MyAppImage:1.0.0"
            "DockerPublishContainerPort"="8080"
        }

        Test-Path $targetDockerfile | Should Be $true
        Test-Path $targetDockerfile2 | Should Be $true
        $(Get-Content $targetDockerfile -Raw).Trim() | Should BeExactly $(Get-Content $tokenReplacedDockerfilePath -Raw).Trim()
    }
    
    It 'Verify the custom Dockerfile is located and tokens are replaced correctly' {
    
        Publish-AspNet -packOutput $dockerPackDir -publishProperties @{
            'WebPublishMethod'='Docker'
            "DockerBaseImageName"="MyAppImage:1.0.0"
            "DockerPublishContainerPort"="8080"
            "DockerfileRelativePath"="..\..\CustomDockerfile"
        }
        
        Test-Path $targetDockerfile | Should Be $true
        Test-Path $targetDockerfile2 | Should Be $true
        $(Get-Content $targetDockerfile -Raw).Trim() | Should BeExactly $(Get-Content $tokenReplacedDockerfilePath -Raw).Trim()
    }
}

Describe 'Test-WebPage unit tests' {

    It 'Verify the Test-WebPage return false for non-existing webpage' {
        Test-WebPage "http://somenonexistingpage.com/" 1 | Should Be $false
    }
    
    It 'Verify the Test-WebPage return true for existing webpage' {
        Test-WebPage "http://www.microsoft.com" 1 | Should Be $true
    }
}
