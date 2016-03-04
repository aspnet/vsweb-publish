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

$env:IsDeveloperMachine = $true

if(Test-Path $modulePath){
    'Importing module from [{0}]' -f $modulePath | Write-Verbose

    if((Get-Module $moduleName)){ Remove-Module $moduleName -Force }
    
    Import-Module $modulePath -PassThru -DisableNameChecking | Out-Null
}
else{
    throw ('Unable to find module at [{0}]' -f $modulePath )
}

Describe 'Create manifest xml file tests' {
	It 'generate source manifest file for iisApp provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase00'
        $webRootName = 'wwwroot'
        $iisAppPath = Join-Path $rootDir "$webRootName"
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'WwwRootOut'="$webRootName"
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -isSource
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'SourceManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq "$iisAppPath") | should be $true 
    }
    
	It 'generate dest manifest file for iisApp provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase01'
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'DeployIisAppPath'='WebSiteName'
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'DestManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq 'WebSiteName') | should be $true        
    }   
    
	It 'generate source manifest file for FileSystem provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase20'
        $webRootName = 'wwwroot'
        $publishProperties =@{
            'WebPublishMethod'='FileSystem'           
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -isSource
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'SourceManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.contentPath.path -eq "$rootDir") | should be $true         
    }
    
	It 'generate dest manifest file for FileSystem provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase21'
        $webRootName = 'wwwroot'
        $publishURL = 'c:\Samples'
        $publishProperties =@{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishURL"
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'DestManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.contentPath.path -eq "$publishURL") | should be $true        
    }    
    
	It 'generate source manifest file for Package provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase30'        
        $webRootName = 'wwwroot'
        $iisAppPath = Join-Path $rootDir "$webRootName"
        $publishProperties =@{
            'WebPublishMethod'='Package'
            'WwwRootOut'='wwwroot'
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -isSource
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'SourceManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq "$iisAppPath") | should be $true        
    }         
}