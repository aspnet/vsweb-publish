[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

function New-ConfigJsonFolder {	
	[cmdletbinding()]
	param(
		[Parameter(Mandatory = $true,Position=0)]
		[bool]$compileSource,
		[Parameter(Mandatory = $true,Position=1)]
		[string]$projectName,
		[Parameter(Position=2)]
		[string]$projectVersion,
		[Parameter(Mandatory = $true,Position=3)]
		$rootDir		
	)
	process {
		$resultPath = ''
		$appRootName = 'approot'
		$appRootPath = Join-Path $rootDir $appRootName
		if (-not (Test-Path -Path $appRootPath)) {
			New-Item -Path $rootDir -Name $appRootName -ItemType "directory" | Out-Null
		}
		if ($compileSource) {
            if ([string]::IsNullOrEmpty($projectVersion)) {
                throw 'ProjectVersion cannot be empty while CompileSource is true'
            }
			$packageName = 'packages'
			$packPath = Join-Path $appRootPath $packageName
			if (-not (Test-Path -Path $packPath)) {
				New-Item -Path $appRootPath -Name $packageName -ItemType "directory" | Out-Null
			}
			$projectNamePath = Join-Path $packPath $projectName
			if (-not (Test-Path -Path $projectNamePath)) {
				New-Item -Path $packPath -Name $projectName -ItemType "directory" | Out-Null
			}			
			$projectVersionPath = Join-Path $projectNamePath $projectVersion
			if (-not (Test-Path -Path $projectVersionPath)) {
				New-Item -Path $projectNamePath -Name $projectVersion -ItemType "directory" | Out-Null
			}
			$upperRoot = Join-Path $projectVersionPath 'root'
			if (-not (Test-Path -Path $upperRoot)) {
				New-Item -Path $projectVersionPath -Name 'root' -ItemType "directory" | Out-Null
			}		
			$resultPath = $upperRoot
		}
		else {
			$srcName = 'src'
			$srcPath = Join-Path $appRootPath $srcName
			if (-not (Test-Path -Path $srcPath)) {
				New-Item -Path $appRootPath -Name $srcName -ItemType "directory" | Out-Null
			}		
			$projectNamePath = Join-Path $srcPath $projectName
			if (-not (Test-Path -Path $projectNamePath)) {
				New-Item -Path $srcPath -Name $projectName -ItemType "directory" | Out-Null
			}	
			$resultPath = $projectNamePath
		}
		
		$resultPath 
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

Describe 'Find Config.json path test' {     
	It 'find a file which exists when CompileSource is true and ProjectVersion is valid' {
		$rootDir = Join-Path $TestDrive 'ConfigFilePathCase00'
	
		$projectName = "TestWebApp"
		$projectVersion = "1.0.0"
		$compileSource = $true 
        # create related web application path for test purpose
		$jsonPath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir

		$configJsonPath = Join-Path $jsonPath 'config.json'
		# create an empty config.json for test purpose
		" " | Set-Content -Path $configJsonPath -Force		
		
		$result = InternalGet-ConfigFile -packOutput $rootDir -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion
		
		(Test-Path -Path $result) | should be $true		
	}
    
	It 'find a file which exists when CompileSource is true and ProjectVersion is NOT valid' {
		$rootDir = Join-Path $TestDrive 'ConfigFilePathCase01'
	
		$projectName = "TestWebApp"
		$projectVersion = '1.0.0'
        $projectVersionInTest = '2.0.0'
		$compileSource = $true   
        # create related web application path for test purpose
		$jsonPath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir

		$configJsonPath = Join-Path $jsonPath 'config.json'
		# create an empty config.json for test purpose
		" " | Set-Content -Path $configJsonPath -Force		
		
		$result = InternalGet-ConfigFile -packOutput $rootDir -compileSource $compileSource -projectName $projectName -projectVersion $projectVersionInTest
		
        (Test-Path -Path result) | should be $false
	}    
	
	It 'find a file which did NOT exist when CompileSource is true and ProjectVersion is valid' {
		$rootDir = Join-Path $TestDrive 'ConfigFilePathCase10'

		$projectName = "TestWebApp"
		$projectVersion = '1.0.0'
		$compileSource = $true
        # create related web application path for test purpose
		New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir				
		
		$result = InternalGet-ConfigFile -packOutput $rootDir -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion
		
		(Test-Path -Path result) | should be $false
		
	}	
    
	It 'find a file which did NOT exist when CompileSource is true and ProjectVersion is NOT valid' {
		$rootDir = Join-Path $TestDrive 'ConfigFilePathCase11'

		$projectName = "TestWebApp"
		$projectVersion = '1.0.0'
        $projectVersionInTest = '2.0.0'
		$compileSource = $true
        # create related web application path for test purpose
		New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir				
		
		$result = InternalGet-ConfigFile -packOutput $rootDir -compileSource $compileSource -projectName $projectName -projectVersion $projectVersionInTest
        
        (Test-Path -Path result) | should be $false
	}    
	
	It 'find a file which exists when CompileSource is false' {
		$rootDir = Join-Path $TestDrive 'ConfigFilePathCase20'

		$projectName = "TestWebApp"
		$compileSource = $false
        # create related web application path for test purpose
		$jsonPath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -rootDir $rootDir
		$configJsonPath = Join-Path $jsonPath 'config.json'
		# create an empty config.json for test purpose
		" " | Set-Content -Path $configJsonPath -Force		
		#
		$result = InternalGet-ConfigFile -packOutput $rootDir -compileSource $compileSource -projectName $projectName
        
		(Test-Path -Path $result) | should be $true	

	}
    
	It 'find a file which exists when CompileSource is false and ProjectVersion is random' {
		$rootDir = Join-Path $TestDrive 'ConfigFilePathCase21'

		$projectName = "TestWebApp"
		$compileSource = $false
        $projectVersion = '1.2.3'
        # create related web application path for test purpose
		$jsonPath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir
		$configJsonPath = Join-Path $jsonPath 'config.json'
		# create an empty config.json for test purpose
		" " | Set-Content -Path $configJsonPath -Force		
		#
		$result = InternalGet-ConfigFile -packOutput $rootDir -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion
        
		(Test-Path -Path $result) | should be $true	

	}    
	
	It 'find a file which did NOT exist when CompileSource is false' {
		$rootDir = Join-Path $TestDrive 'ConfigFilePathCase3'
	
		$projectName = "TestWebApp"
		$compileSource = $false
        # create related web application path for test purpose
		New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -rootDir $rootDir	
		#
		$result = InternalGet-ConfigFile -packOutput $rootDir -compileSource $false -projectName $projectName
        
		(Test-Path -Path result) | should be $false
		
	}	
    
	It 'find a file which did NOT exist when CompileSource is false and ProjectVersion is random' {
		$rootDir = Join-Path $TestDrive 'ConfigFilePathCase31'
	
		$projectName = "TestWebApp"
		$compileSource = $false
        $projectVersion = '1.2.3'
        # create related web application path for test purpose
		New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir	
		#
		$result = InternalGet-ConfigFile -packOutput $rootDir -compileSource $false -projectName $projectName -projectVersion $projectVersion
        
		(Test-Path -Path result) | should be $false
		
	}    
}

Describe 'create/update Config.Production.Json file test' {     
	It 'create a new config.production.json file - null connection string object and CompileSource=false' {		
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase00'

		$environmentName = "Production"
		$compileSource = $false
		$projectName = "TestWebApp"
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -rootDir $rootDir 
		# null connection string
		$defaultConnStrings = $null				
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName
		
        $result = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($result = '{}') | should be $true	
	
	}
	
	It 'create a new config.production.json file - null connection string object and CompileSource=true and ProjectVersion is valid' {		
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase01'

		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir 
		# null connection string
		$defaultConnStrings = $null				
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -connectionString $defaultConnStrings	
		
        $result = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($result = '{}') | should be $true	
	}	
	
	It 'create a new config.production.json file - null connection string object and CompileSource=true and ProjectVersion is NOT valid' {		
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase02'

		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $projectVersionInTest = '2.0.0'
		# create related web application path for test purpose
		New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir 
		# null connection string			
		
		{InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersionInTest} | should throw 	
	
	}	
	
	It 'create a new config.production.json file - empty connection string object and CompileSource=false' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase10'
		
		$environmentName = "Production"
		$compileSource = $false
		$projectName = "TestWebApp"
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir 
		# empty connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -connectionString $defaultConnStrings	
		
        $result = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($result = '{}') | should be $true	
	}
	
	It 'create a new config.production.json file - empty connection string object and CompileSource=true and ProjectVersion is valid' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase11'
		
		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir 
		# empty connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -connectionString $defaultConnStrings	
		
        $result = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($result = '{}') | should be $true	
	}
	
	It 'create a new config.production.json file - empty connection string object and CompileSource=true and ProjectVersion is NOT valid' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase11'
		
		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = "1.0.0"
        $projectVersionInTest = '2.0.0'
		# create related web application path for test purpose
		New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir 
		# empty connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'			

		{InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersionInTest -connectionString $defaultConnStrings} | should throw

    }

	It 'create a new config.production.json file - non-empty connection string object and CompileSource=false' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase20'
		
		$environmentName = "Production"
		$compileSource = $false
		$projectName = "TestWebApp"
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -rootDir $rootDir 		
		# non-emtpy connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
		$defaultConnStrings.Add("connection1","server=server1;database=db1;")
		$defaultConnStrings.Add("connection2","server=server2;database=db2;")			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -connectionString $defaultConnStrings	
		
        $finalJsonContent = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($finalJsonContent -ne '{}') | should be $true
		$finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.Data.connection1.ConnectionString -eq 'server=server1;database=db1;') | should be $true 
        ($finalJsonObj.Data.connection2.ConnectionString -eq 'server=server2;database=db2;') | should be $true         	
	}

	It 'create a new config.production.json file - non-empty connection string object and CompileSource=true and ProjectVersion is valid' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase21'
		
		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir 		
		# non-emtpy connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
		$defaultConnStrings.Add("connection1","server=server1;database=db1;")
		$defaultConnStrings.Add("connection2","server=server2;database=db2;")			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -connectionString $defaultConnStrings

        $finalJsonContent = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($finalJsonContent -ne '{}') | should be $true
		$finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.Data.connection1.ConnectionString -eq 'server=server1;database=db1;') | should be $true 
        ($finalJsonObj.Data.connection2.ConnectionString -eq 'server=server2;database=db2;') | should be $true
	}
	
	It 'create a new config.production.json file - non-empty connection string object and CompileSource=true and ProjectVersion is NOT valid' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase22'
		
		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $projectVersionInTest = '2.0.0'
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir 		
		# non-emtpy connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
		$defaultConnStrings.Add("connection1","server=server1;database=db1;")
		$defaultConnStrings.Add("connection2","server=server2;database=db2;")			
				
		{InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersionInTest -connectionString $defaultConnStrings} | should throw
	
	}	
		
	It 'update existing config.production.json file - null connection string object with CompileSource=false' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase30'
	
		$environmentName = "Production"
		$compileSource = $false
		$projectName = "TestWebApp"
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# null connection string object
		
        # create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -rootDir $rootDir
        # prepare content of config.production.json for test purpose
		$configProdJsonPath = Join-Path $jsonFilePath ('config.{0}.json' -f $environmentName)
		$originalJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.production.json for test purpose
		$originalJsonContent | Set-Content -Path $configProdJsonPath -Force			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName
			
		$finalJsonContent = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($finalJsonContent -ne '{}') | should be $true
		$finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.Data.DefaultConnection.ConnectionString -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true
	
	}
	
	It 'update existing config.production.json file - null connection string object with CompileSource=true and ProjectVersion is valid' {
	    $rootDir = Join-Path $TestDrive 'ConfigProdJsonCase31'
        
        $environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# null connection string object
        
        # create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -rootDir $rootDir -projectVersion $projectVersion
        # prepare content of config.production.json for test purpose
		$configProdJsonPath = Join-Path $jsonFilePath ('config.{0}.json' -f $environmentName)
		$originalJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.production.json for test purpose
		$originalJsonContent | Set-Content -Path $configProdJsonPath -Force
        
        InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion
        
		$finalJsonContent = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($finalJsonContent -ne '{}') | should be $true
		$finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.Data.DefaultConnection.ConnectionString -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true        
        
	}
	
	It 'update existing config.production.json file - null connection string object with CompileSource=true and ProjectVersion is NOT valid' {
	    $rootDir = Join-Path $TestDrive 'ConfigProdJsonCase32'
        
        $environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $projectVersionInTest = '2.0.0'
		# null connection string object
        
        # create related web application path for test purpose
		$jsonPath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -rootDir $rootDir -projectVersion $projectVersion
        # prepare content of config.production.json for test purpose
		$configProdJsonPath = Join-Path $jsonPath ('config.{0}.json' -f $environmentName)
		$originalJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.production.json for test purpose
		$originalJsonContent | Set-Content -Path $configProdJsonPath -Force
        
        {InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersionInTest} | should throw  
        
	}	
	
	It 'update existing config.production.json file - empty connection string object with CompileSource=false' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase40'
		
		$environmentName = "Production"
		$compileSource = $false
		$projectName = "TestWebApp"
		$projectVersion = ''
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# empty connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        # create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir
        # prepare content of config.production.json for test purpose
		$originalJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.Production.json for test purpose
		$originalJsonContent | Set-Content -Path (Join-Path $jsonFilePath $configProdJsonFile) -Force			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -connectionString $defaultConnStrings	         
		
        $finalJsonContent = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($finalJsonContent -ne '{}') | should be $true
		$finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.Data.DefaultConnection.ConnectionString -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true                  
	
	}
	
	It 'update existing config.production.json file - empty connection string object with CompileSource=true and ProjectVersion is valid' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase41'
		
		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
		$projectVersion = '1.0.0'
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		# empty connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        # create related web application path for test purpose
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir
        # prepare content of config.production.json for test purpose
		$originalJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.Production.json for test purpose
		$originalJsonContent | Set-Content -Path (Join-Path $jsonFilePath $configProdJsonFile) -Force			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -connectionString $defaultConnStrings	
		     		
        $finalJsonContent = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($finalJsonContent -ne '{}') | should be $true
		$finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.Data.DefaultConnection.ConnectionString -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true	
	}
	
	It 'update existing config.production.json file - empty connection string object with CompileSource=true and ProjectVersion is NOT valid' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase42'

		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
		$projectVersion = '1.0.0'
        $projectVersionInTest = '2.0.0'
		# empty connection string object
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        # create related web application path for test purpose
		$jsonPath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir
        # prepare content of config.production.json for test purpose
		$configProdJsonPath = Join-Path $jsonPath ('config.{0}.json' -f $environmentName)
		$originalJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.Production.json for test purpose
		$originalJsonContent | Set-Content -Path $configProdJsonPath -Force			
		
		{InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersionInTest -connectionString $defaultConnStrings} | should throw 		     	        
        
	}
	
	It 'update existing config.production.json file - non-empty connection string object with CompileSource=false' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase50'
		
		$environmentName = "Production"
		$compileSource = $false
		$projectName = "TestWebApp"
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
		$defaultConnStrings.Add("connection1","server=server1;database=db1;")
		$defaultConnStrings.Add("connection2","server=server2;database=db2;")
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -rootDir $rootDir
		$originalJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        },
        "connection1" : {
            "ConnectionString": "random text"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.Production.Json for test purpose
		$originalJsonContent | Set-Content -Path (Join-Path $jsonFilePath $configProdJsonFile) -Force			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -connectionString $defaultConnStrings	
		
        $finalJsonContent = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($finalJsonContent -ne '{}') | should be $true
		$finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.Data.DefaultConnection.ConnectionString -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true     
        ($finalJsonObj.Data.connection1.ConnectionString -eq 'server=server1;database=db1;') | should be $true
        ($finalJsonObj.Data.connection2.ConnectionString -eq 'server=server2;database=db2;') | should be $true 

	}
	
	It 'update existing config.production.json file - non-empty connection string object with CompileSource=true and ProjectVersion is valid' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase51'
		
		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $configProdJsonFile = 'config.{0}.json' -f $environmentName
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
		$defaultConnStrings.Add("connection1","server=server1;database=db1;")
		$defaultConnStrings.Add("connection2","server=server2;database=db2;")
		$jsonFilePath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir
		$originalJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        },
        "connection1" : {
            "ConnectionString": "random text"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.Production.Json for test purpose
		$originalJsonContent | Set-Content -Path (Join-Path $jsonFilePath $configProdJsonFile) -Force			
		
		InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -connectionString $defaultConnStrings	
		
        $finalJsonContent = Get-Content (join-path $jsonFilePath $configProdJsonFile) -Raw
		($finalJsonContent -ne '{}') | should be $true
		$finalJsonObj = ConvertFrom-Json -InputObject $finalJsonContent
        ($finalJsonObj.Data.DefaultConnection.ConnectionString -eq 'a-sql-server-connection-string-in-config-json') | should be $true 
        ($finalJsonObj.TestData -eq 'TestValue') | should be $true
        ($finalJsonObj.Data.connection1.ConnectionString -eq 'server=server1;database=db1;') | should be $true
        ($finalJsonObj.Data.connection2.ConnectionString -eq 'server=server2;database=db2;') | should be $true 
	}
	
	It 'update existing config.production.json file - non-empty connection string object with CompileSource=true and ProjectVersion is NOT valid' {
		$rootDir = Join-Path $TestDrive 'ConfigProdJsonCase52'
		
		$environmentName = "Production"
		$compileSource = $true
		$projectName = "TestWebApp"
        $projectVersion = '1.0.0'
        $projectVersionInTest = '2.0.0'
		$defaultConnStrings = New-Object 'system.collections.generic.dictionary[[string],[string]]'
		$defaultConnStrings.Add("connection1","server=server1;database=db1;")
		$defaultConnStrings.Add("connection2","server=server2;database=db2;")
		$jsonPath = New-ConfigJsonFolder -compileSource $compileSource -projectName $projectName -projectVersion $projectVersion -rootDir $rootDir
		$configProdJsonPath = Join-Path $jsonPath ('config.{0}.json' -f $environmentName)
		$configProdJsonContent = @'
{
    "Data": {
        "DefaultConnection": {
            "ConnectionString": "a-sql-server-connection-string-in-config-json"
        }
    },
    "TestData" : "TestValue"
}				
'@
		# create config.Production.Json for test purpose
		$configProdJsonContent | Set-Content -Path $configProdJsonPath -Force			
		
		{InternalSave-ConfigEnvironmentFile -packOutput $rootDir -environmentName $environmentName -compileSource $compileSource -projectName $projectName -projectVersion $projectVersionInTest -connectionString $defaultConnStrings} | should throw 
		
	}
}

Describe 'generate EF migration TSQL script test' {
    It 'Invalid DNXExePath system variable test' {
        $rootDir = Join-Path $TestDrive 'EFMigrations00'
        # create test folder
        if (Test-Path -Path $rootDir) {
            remove-item $rootDir -Force -Recurse
        }
        mkdir $rootDir
        
        $originalDNXExePath = $env:DNXExePath                 
        
        try
        {
            $env:DNXExePath = 'random-name'
            $dnxAppHost = 'Microsoft.Dnx.ApplicationHost'
            $EFConnectionString = @{'dbContext1'='some-EF-connection-string'}
            {InternalGet-EFMigrationScript -packOutput $rootDir -appSourcePath $rootDir -DNXAppHost $dnxAppHost -EFConnectionString $EFConnectionString} | should throw
        }
        finally
        {
            $env:DNXExePath = $originalDNXExePath
        }
    }
}    

Describe 'create manifest xml file tests' {
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
    
	It 'generate source manifest file for iisApp provider and one dbFullSql provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase10'
        $webRootName = 'wwwroot'
        $iisAppPath = Join-Path $rootDir "$webRootName"
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'WwwRootOut'="$webRootName"
        }
        $sqlFile = 'c:\Samples\dbContext.sql'
        $EFMigration = @{
            'dbContext1'="$sqlFile"
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -EFMigrationData $EFMigration -isSource
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'SourceManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq "$iisAppPath") | should be $true 
        ($xmlResult.sitemanifest.dbFullSql.path -eq "$sqlFile") | should be $true 
    }
    
	It 'generate dest manifest file for iisApp provider and one dbFullSql provider' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase11'
        $sqlConnString = 'server=serverName;database=dbName;user id=userName;password=userPassword;'
        $EFMigration = @{
            'dbContext1'="$sqlConnString"
        }        
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'DeployIisAppPath'='WebSiteName'
            'EFMigrations'=$EFMigration
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -EFMigrationData $EFMigration
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'DestManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq 'WebSiteName') | should be $true
        ($xmlResult.sitemanifest.dbFullSql.path -eq "$sqlConnString") | should be $true 
    }    

	It 'generate source manifest file for iisApp provider and two dbFullSql providers' {
		$rootDir = Join-Path $TestDrive 'ManifestFileCase12'
        $webRootName = 'wwwroot'
        $iisAppPath = Join-Path $rootDir "$webRootName"
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'WwwRootOut'="$webRootName"
        }
        $sqlFile1 = 'c:\Samples\dbContext1.sql'
        $sqlFile2 = 'c:\Samples\dbContext2.sql'
        $EFMigration = @{
            'dbContext1'="$sqlFile1"
            'dbContext2'="$sqlFile2"
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -EFMigrationData $EFMigration -isSource
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
		$rootDir = Join-Path $TestDrive 'ManifestFileCase13'
        $sqlConnString1 = 'This-is-a-fake-string-for-connection-string-1'
        $sqlConnString2 = 'This-is-a-fake-string-for-connection-string-2'
        $EFMigration = @{
            'dbContext1'="$sqlConnString1"
            'dbContext2'="$sqlConnString2"
        }        
        $publishProperties =@{
            'WebPublishMethod'='MSDeploy'
            'DeployIisAppPath'='WebSiteName'
            'EFMigrations'=$EFMigration
        }
        
        $xmlFile = InternalNew-ManifestFile -packOutput $rootDir -publishProperties $publishProperties -EFMigrationData $EFMigration
        # verify
        (Test-Path -Path $xmlFile) | should be $true
        $pubArtifactDir = Join-Path $TestDrive 'obj'
        ((Join-Path $pubArtifactDir 'DestManifest.xml') -eq $xmlFile.FullName) | should be $true 
        $xmlResult = [xml](Get-Content $xmlFile -Raw)
        ($xmlResult.sitemanifest.iisApp.path -eq 'WebSiteName') | should be $true
        ($xmlResult.sitemanifest.dbFullSql[0].path -eq "$sqlConnString1") | should be $true         
        ($xmlResult.sitemanifest.dbFullSql[1].path -eq "$sqlConnString2") | should be $true
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
