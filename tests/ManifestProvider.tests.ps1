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
        $iisAppPath = $rootDir
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
        }
		if(!(Test-Path rootDir))
		{
			mkdir $rootDir
		}

        [System.Collections.ArrayList]$providerDataArray = @()

        $iisAppSourceKeyValue=@{"iisApp" = @{"path"=$iisAppPath}}
        $providerDataArray.Add($iisAppSourceKeyValue) | Out-Null

        
        $xmlFile = GenerateInternal-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -providerDataArray $providerDataArray -manifestFileName 'SourceManifest.xml'
        # verify
        (Test-Path -Path $xmlFile) | should be $true

        $pubArtifactDir = [io.path]::combine([io.path]::GetTempPath(),'PublishTemp','obj','ManifestFileCase00')
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
        if(!(Test-Path rootDir))
		{
			mkdir $rootDir
		}

        [System.Collections.ArrayList]$providerDataArray = @()

        $iisAppDestinationKeyValue=@{"iisApp" = @{"path"=$publishProperties['DeployIisAppPath']}}
        $providerDataArray.Add($iisAppDestinationKeyValue) | Out-Null
		
        $xmlFile = GenerateInternal-ManifestFile -packOutput $rootDir -publishProperties $publishProperties  -providerDataArray $providerDataArray -manifestFileName 'DestinationManifest.xml'
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = [io.path]::combine([io.path]::GetTempPath(),'PublishTemp','obj','ManifestFileCase01')
        ((Join-Path $pubArtifactDir 'DestinationManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq 'WebSiteName') | should be $true        
    }   
    
	It 'generate source manifest file for FileSystem provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase20'
        $webRootName = 'wwwroot'
        $publishProperties =@{
            'WebPublishMethod'='FileSystem'           
        }
        if(!(Test-Path rootDir))
		{
			mkdir $rootDir
		}

        [System.Collections.ArrayList]$providerDataArray = @()
        $contentPathSourceKeyValue=@{"contentPath" = @{"path"=$rootDir}}
        $providerDataArray.Add($contentPathSourceKeyValue) | Out-Null
		
        $xmlFile = GenerateInternal-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -providerDataArray $providerDataArray -manifestFileName 'SourceManifest.xml'
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = [io.path]::combine([io.path]::GetTempPath(),'PublishTemp','obj','ManifestFileCase20')
        ((Join-Path $pubArtifactDir 'SourceManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.contentPath.path -eq "$rootDir") | should be $true         
    }
    
	It 'generate dest manifest file for FileSystem provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase21'
		if(!(Test-Path rootDir))
		{
			mkdir $rootDir
		}
        $webRootName = 'wwwroot'
        $publishURL = 'c:\Samples'
        $publishProperties =@{
            'WebPublishMethod'='FileSystem'
            'publishUrl'="$publishURL"
        }
        
        [System.Collections.ArrayList]$providerDataArray = @()
        $contentPathDestinationKeyValue=@{"contentPath" = @{"path"=$publishUrl}}
        $providerDataArray.Add($contentPathDestinationKeyValue) | Out-Null

        $xmlFile = GenerateInternal-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -providerDataArray $providerDataArray -manifestFileName 'DestinationManifest.xml'
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = [io.path]::combine([io.path]::GetTempPath(),'PublishTemp','obj','ManifestFileCase21')
        ((Join-Path $pubArtifactDir 'DestinationManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.contentPath.path -eq "$publishURL") | should be $true        
    }    
    
	It 'generate source manifest file for Package provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase30'  
		if(!(Test-Path rootDir))
		{
			mkdir $rootDir
		}		
        $iisAppPath = $rootDir
        $publishProperties =@{
            'WebPublishMethod'='Package'
        }
        
        [System.Collections.ArrayList]$providerDataArray = @()
        $iisAppSourceKeyValue=@{"iisApp" = @{"path"=$rootDir}}
        $providerDataArray.Add($iisAppSourceKeyValue) | Out-Null
        $xmlFile = GenerateInternal-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -providerDataArray $providerDataArray -manifestFileName 'SourceManifest.xml'
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = [io.path]::combine([io.path]::GetTempPath(),'PublishTemp','obj','ManifestFileCase30')
        ((Join-Path $pubArtifactDir 'SourceManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq "$iisAppPath") | should be $true        
    }         
}