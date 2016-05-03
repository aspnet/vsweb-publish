[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

function InternalNew-TestFolder {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,Position=0)]
        [string]$testDrivePath,
        [Parameter(Mandatory = $true,Position=1)]
        [string]$folderName
    )
    process {
        if ([string]::IsNullOrWhiteSpace($folderName)) {
            throw 'folder name cannot be empty or white space'
        }
        if (!(Test-Path -Path $testDrivePath)) {
            throw 'The path of test drive does not exist'
        }
        $targetFoler = Join-Path $testDrivePath $folderName
        if (!(Test-Path -Path $targetFoler)) {
            New-Item -Path $testDrivePath -Name $folderName -ItemType "directory" | Out-Null
        }        
    }
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

Describe 'create/update appSettings.Production.Json file test' {
    It 'create a new appSettings.production.json file - null connection string object' {
        $testFolderName = 'ConfigProdJsonCase01'
        $rootDir = Join-Path $TestDrive $testFolderName
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $environmentName = 'Production'
        $configProdJsonFile = 'appsettings.{0}.json' -f $environmentName

        # null connection string
        $defaultConnStrings = $null
        InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -connectionString $defaultConnStrings 
        # verify
        $result = Get-Content (Join-Path $rootDir $configProdJsonFile) -Raw
        $emptyTarget = @'
{

}
'@
        ($result.Trim() -eq $emptyTarget) | should be $true 
    }
    
    It 'create a new appSettings.production.json file - empty connection string object' {
        $testFolderName = 'ConfigProdJsonCase11'
        $rootDir = Join-Path $TestDrive $testFolderName
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $environmentName = 'Production'
        $configProdJsonFile = 'appsettings.{0}.json' -f $environmentName

        # empty connection string object
        $defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        
        InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -connectionString $defaultConnStrings 
        
        $result = Get-Content (Join-Path $rootDir $configProdJsonFile) -Raw
        $emptyTarget = @'
{

}
'@
        ($result.Trim() -eq $emptyTarget) | should be $true 
    }

    It 'create a new appSettings.production.json file - non-empty connection string object' {       
        $testFolderName = 'ConfigProdJsonCase21'
        $rootDir = Join-Path $TestDrive $testFolderName
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $environmentName = 'Production'
        $configProdJsonFile = 'appsettings.{0}.json' -f $environmentName
        # non-emtpy connection string object
        $defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        $defaultConnStrings.Add("connection1","server=server1;database=db1;")
        $defaultConnStrings.Add("connection2","server=server2;database=db2;")           
        
        InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -connectionString $defaultConnStrings

        $finalJsonContent = Get-Content (join-path $rootDir $configProdJsonFile) -Raw
        $emptyTarget = @'
{

}
'@      
        ($finalJsonContent.Trim() -ne $emptyTarget) | should be $true
        $finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.ConnectionStrings.connection1 -eq 'server=server1;database=db1;') | should be $true 
        ($finalJsonObj.ConnectionStrings.connection2 -eq 'server=server2;database=db2;') | should be $true

    }
    
    It 'update existing appSettings.production.json file - null connection string object' {
        $testFolderName = 'ConfigProdJsonCase31'
        $rootDir = Join-Path $TestDrive $testFolderName
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $environmentName = 'Production'
        $configProdJsonFile = 'appSettings.{0}.json' -f $environmentName
        # null connection string object

        # prepare content of appSettings.production.json for test purpose
        $configProdJsonPath = Join-Path $rootDir $configProdJsonFile
        $originalJsonContent = @'
{
    "ConnectionStrings": {
        "DefaultConnection": "a-sql-server-connection-string-in-config-json"
    },
    "TestData" : "TestValue"
}               
'@
        # create appSettings.production.json for test purpose
        $originalJsonContent | Set-Content -Path $configProdJsonPath -Force
        
        InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName
        
        $finalJsonContent = Get-Content (join-path $rootDir $configProdJsonFile) -Raw
        $emptyTarget = @'
{

}
'@      
        ($finalJsonContent -ne $emptyTarget) | should be $true
        $finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.ConnectionStrings.DefaultConnection -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true        
        
    }    
 
    It 'update existing appSettings.production.json file - empty connection string object' {
        $testFolderName = 'ConfigProdJsonCase41'
        $rootDir = Join-Path $TestDrive $testFolderName
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $environmentName = 'Production'
        $configProdJsonFile = 'appSettings.{0}.json' -f $environmentName
        # empty connection string object
        $defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        # prepare content of appSettings.production.json for test purpose
        $originalJsonContent = @'
{
    "ConnectionStrings": {
        "DefaultConnection": "a-sql-server-connection-string-in-config-json"
    },
    "TestData" : "TestValue"
}               
'@
        # create appSettings.Production.json for test purpose
        $originalJsonContent | Set-Content -Path (Join-Path $rootDir $configProdJsonFile) -Force            
        
        InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -connectionString $defaultConnStrings 
                    
        $finalJsonContent = Get-Content (join-path $rootDir $configProdJsonFile) -Raw
        $emptyTarget = @'
{

}
'@      
        ($finalJsonContent -ne $emptyTarget) | should be $true
        $finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.ConnectionStrings.DefaultConnection -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true  
    }
      
    It 'update existing appSettings.production.json file - non-empty connection string object' {
        $testFolderName = 'ConfigProdJsonCase51'
        $rootDir = Join-Path $TestDrive $testFolderName
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $environmentName = 'Production'
        $compileSource = $true
        $projectName = 'TestWebApp'
        $projectVersion = '1.0.0'
        $configProdJsonFile = 'appSettings.{0}.json' -f $environmentName
        $defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        $defaultConnStrings.Add("connection1","server=server1;database=db1;")
        $defaultConnStrings.Add("connection2","server=server2;database=db2;")

        $originalJsonContent = @'
{
    "ConnectionStrings": {
        "DefaultConnection": "a-sql-server-connection-string-in-config-json",
        "connection1": "random text"
    },
    "TestData" : "TestValue"
}               
'@
        # create appSettings.Production.Json for test purpose
        $originalJsonContent | Set-Content -Path (Join-Path $rootDir $configProdJsonFile) -Force
        
        InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -connectionString $defaultConnStrings 
        
        $finalJsonContent = Get-Content (Join-Path $rootDir $configProdJsonFile) -Raw
        $emptyTarget = @'
{

}
'@      
        ($finalJsonContent -ne $emptyTarget) | should be $true
        $finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.ConnectionStrings.DefaultConnection -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true
        ($finalJsonObj.ConnectionStrings.connection1 -eq 'server=server1;database=db1;') | should be $true
        ($finalJsonObj.ConnectionStrings.connection2 -eq 'server=server2;database=db2;') | should be $true 
    }
}

Describe 'generate EF migration TSQL script test' {
	
	It 'EF T-SQL will be copied to script folder in file system publishing test' {
		$DBContextName = 'BlogsContext'
		$testFolderName = 'EFMigrationsInFileSystem00'
		$outputFolderName = 'EFMigrationsInFileSystem00-output'
		$rootDir = Join-Path $TestDrive $testFolderName
		$outputDir = Join-Path $TestDrive $outputFolderName
		# create test folder
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
		InternalNew-TestFolder -testDrivePath $TestDrive -folderName $outputFolderName
		# copy sample to test folder
        Copy-Item .\SampleFiles\DotNetWebApp\* $rootDir -recurse -Force
		
		$originalExePath = $env:dotnetinstallpath
		
		try
		{
			$env:dotnetinstallpath = '' # force the script to find dotnet.exe
			$EFConnectionString = @{"$DBContextName"='some-EF-migrations-string'}
			#run dotnet restore first to generate project.lock.json
			$dotnetpath = InternalGet-DotNetExePath
			(Test-Path -Path $dotnetpath) | should be $true 
			Execute-Command $dotnetpath 'restore' "$rootDir\src"
			
		    Publish-AspNet -packOutput $outputDir -publishProperties @{
                'WebPublishMethod'='FileSystem'
                'publishUrl'="$outputDir"
				'ProjectPath'="$rootDir\src"
				'EfMigrations'=$EFConnectionString
            }		
		}
		finally
		{
			$env:dotnetinstallpath = $originalExePath
		}
		
		(Test-Path "$outputDir\script") | should be $true 
		(Test-Path "$outputDir\script\$DBContextName.sql") | should be $true 
	}
	
    It 'Invalid dotnetExePath system variable test' {
        $testFolderName = 'EFMigrations00'
        $rootDir = Join-Path $TestDrive $testFolderName
        # create test folder
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $originalExePath = $env:dotnetinstallpath
        
        try
        {
            $env:dotnetinstallpath = 'pretend-invalid-path'
            $EFConnectionString = @{'dbContext1'='some-EF-connection-string'}
            {InternalGet-EFMigrationScript -projectPath '' -packOutput $rootDir -EFConnectionString $EFConnectionString} | should throw
        }
        finally
        {
            $env:dotnetinstallpath = $originalExePath
        }
    } 
     
    It 'generate ef migration file test' {
        $testFolderName = 'EFMigrations01'
        $rootDir = Join-Path $TestDrive $testFolderName
        # create test folder
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        # copy sample to test folder
        Copy-Item .\SampleFiles\DotNetWebApp\* $rootDir -recurse -Force
        
        $originalExePath = $env:dotnetinstallpath
        
        try
        {
            $env:dotnetinstallpath = '' # force the script to find dotnet.exe
            $EFConnectionString = @{'BlogsContext'='some-EF-migrations-string'}
            $dotnetpath = InternalGet-DotNetExePath
            (Test-Path -Path $dotnetpath) | should be $true 
            Execute-Command $dotnetpath 'restore' "$rootDir\src"
            $sqlFiles = InternalGet-EFMigrationScript -projectPath "$rootDir\src" -packOutput "$rootDir\src" -EFConnectionString $EFConnectionString
            ($sqlFiles -eq $null) | Should be $false
            ($sqlFiles.Values.Count -gt 0) | should be $true
            foreach ($file in $sqlFiles.Values) {
                (Test-Path -Path $file) | should be $true
            }
        }
        finally
        {
            $env:dotnetinstallpath = $originalExePath
        }
    }
}    

Describe 'create manifest xml file tests' {   
    It 'generate source manifest file for iisApp provider and one dbFullSql provider' {
        $testFolderName = 'ManifestFileCase10'
        $rootDir = Join-Path $TestDrive $testFolderName
        # create test folder
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $webRootName = 'wwwroot'
        $iisAppPath = $rootDir 
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'WwwRootOut'="$webRootName"
        }
        $sqlFile = 'c:\Samples\dbContext.sql'
        $EFMigration = @{
            'dbContext1'="$sqlFile"
        }
        $efData = @{
            'EFSqlFile'=$EFMigration
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -EFMigrationData $efData -isSource
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'SourceManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq "$iisAppPath") | should be $true 
        ($xmlResult.sitemanifest.dbFullSql.path -eq "$sqlFile") | should be $true 
    }
    
    It 'generate dest manifest file for iisApp provider and one dbFullSql provider' {
        $testFolderName = 'ManifestFileCase11'
        $rootDir = Join-Path $TestDrive $testFolderName
        # create test folder
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $sqlConnString = 'server=serverName;database=dbName;user id=userName;password=userPassword;'
        $EFMigration = @{}
        $DBConnStrings = @{
            'connString1'="$sqlConnString"
        }
        $efData = @{
            'EFSqlFile'=$EFMigration
        }
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'DeployIisAppPath'='WebSiteName'
            'EfMigrations'=$EFMigration
            'DestinationConnectionStrings'=$DBConnStrings
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -EFMigrationData $efData
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'DestManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq 'WebSiteName') | should be $true
        ($xmlResult.sitemanifest.dbFullSql.path -eq "$sqlConnString") | should be $true 
    }    

    It 'generate source manifest file for iisApp provider and two dbFullSql providers' {
        $testFolderName = 'ManifestFileCase12'
        $rootDir = Join-Path $TestDrive $testFolderName
        # create test folder
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $webRootName = 'wwwroot'
        $iisAppPath = $rootDir
        $sqlFile1 = 'c:\Samples\dbContext1.sql'
        $sqlFile2 = 'c:\Samples\dbContext2.sql'
        $EFMigration = @{
            'dbContext1'="$sqlFile1"
            'dbContext2'="$sqlFile2"
        }
        $efData = @{
            'EFSqlFile'=$EFMigration
        }
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'WwwRootOut'="$webRootName"
            'EfMigrations'=$EFMigration
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -EFMigrationData $efData -isSource
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'SourceManifest.xml') -eq $xmlFile.FullName) | should be $true
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq "$iisAppPath") | should be $true 
        ($xmlResult.sitemanifest.dbFullSql[0].path -eq "$sqlFile1") | should be $true 
        ($xmlResult.sitemanifest.dbFullSql[1].path -eq "$sqlFile2") | should be $true 
    }
    
    It 'generate dest manifest file for iisApp provider and two dbFullSql providers' {
        $testFolderName = 'ManifestFileCase13'
        $rootDir = Join-Path $TestDrive $testFolderName
        # create test folder
        InternalNew-TestFolder -testDrivePath $TestDrive -folderName $testFolderName
        
        $firstString = 'server=aaa;database=bbb;user id=ccc;password=ddd;'
        $secondString = 'server=www;database=xxx;user id=yyy;password=zzz;'
        $connStrings = @{
            'dbContext1'="$firstString"
            'dbContext2'="$secondString"
        }
        $EFMigration = @{}
        $efData = @{}
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'DeployIisAppPath'='WebSiteName'
            'EfMigrations'=$EFMigration
            'DestinationConnectionStrings'=$connStrings
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -EFMigrationData $efData
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'DestManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq 'WebSiteName') | should be $true
        ($xmlResult.sitemanifest.dbFullSql[0].path -eq "$firstString") | should be $true
        ($xmlResult.sitemanifest.dbFullSql[1].path -eq "$secondString") | should be $true
    }
}