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

Describe 'Register-AspnetPublishHandler tests' {   
    It 'Adds a handler and verifies it' {
        [scriptblock]$customhandler = {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            'Inside custom handler here' | Write-Output
        }

        Register-AspnetPublishHandler -name 'customhandler' -handler $customhandler

        Get-AspnetPublishHandler -name 'customhandler' | Should Not Be $null
        Get-AspnetPublishHandler -name 'customhandler' | Should Be $customhandler
        InternalReset-AspNetPublishHandlers
    }

    It 'If a handler is already registered with that name the new one is ignored' {
        [scriptblock]$handler1 = {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            'Inside custom handler1 here' | Write-Output
        }

        [scriptblock]$handler2 = {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            'Inside custom handler2 here' | Write-Output
        }

        Register-AspnetPublishHandler -name 'customhandler' -handler $handler1
        Register-AspnetPublishHandler -name 'customhandler' -handler $handler2

        Get-AspnetPublishHandler -name 'customhandler' | Should Be $handler1
    }

    It 'If a handler is already registered with that name the new will override with force' {
        [scriptblock]$handler1 = {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            'Inside custom handler1 here' | Write-Output
        }

        [scriptblock]$handler2 = {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            'Inside custom handler2 here' | Write-Output
        }

        Register-AspnetPublishHandler -name 'customhandler' -handler $handler1
        Register-AspnetPublishHandler -name 'customhandler' -handler $handler2 -force

        Get-AspnetPublishHandler -name 'customhandler' | Should Be $handler2
    }
}


Describe 'InternalReset-AspNetPublishHandlers' {
    It 'Resets the handlers' {
        Register-AspnetPublishHandler -name 'customhandler2' -handler {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            'Inside custom handler here' | Write-Output
        }

        Get-AspnetPublishHandler -name 'customhandler2'| Should Not Be $null
        
        InternalReset-AspNetPublishHandlers
        {Get-AspnetPublishHandler -name 'customhandler2'} | Should Throw
        Get-AspnetPublishHandler -name 'MSDeploy' | Should Not Be $null
        Get-AspnetPublishHandler -name 'FileSystem' | Should Not Be $null
    }
}

Describe 'Get-AspnetPublishHandler tests' {
    It 'Returns the known handlers' {
        Get-AspnetPublishHandler -name 'MSDeploy' | Should Not Be $null
        Get-AspnetPublishHandler -name 'FileSystem' | Should Not Be $null
    }

    It 'Returns the custom handlers' {
        [ScriptBlock]$handlerBlock = {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            'Inside custom handler here' | Write-Output
        }

        Register-AspnetPublishHandler -name 'customhandler2' -handler $handlerBlock
        
        Get-AspnetPublishHandler -name 'customhandler2' | Should Be $handlerBlock
        InternalReset-AspNetPublishHandlers
    }

    It 'throws when the handler was not found' {
        {Get-AspnetPublishHandler -name 'some-unregistered-name'} | Should Throw
    }
}

Describe 'Get-MSDeploy tests' {
    It 'Returns a value' {
        Get-MSDeploy | Should Not Be $null
    }   
}

Describe 'InternalNormalize-MSDeployUrl tests'{
    # TODO: When we add support for all msdeploy sites we should beef up these test cases
    It 'Returns the correct value for Azure Web Apps' {
        # 'https://{0}/msdeploy.axd' -f $msdeployServiceUrl.TrimEnd(':443')
        $msdeployServiceUrl = 'sayedkdemo2.scm.azurewebsites.net:443'
        $expected = ('https://{0}/msdeploy.axd' -f $msdeployServiceUrl.TrimEnd(':443'))

        InternalNormalize-MSDeployUrl -serviceUrl $msdeployServiceUrl | Should Be $expected
    }

    It 'can use wmsvc'{
        $expectedActual = [ordered]@{
            'contoso'='https://contoso:8172/msdeploy.axd'
            'deploy0924.contoso.com:8172'='https://deploy0924.contoso.com:8172/msdeploy.axd'
            'deploy0924.contoso.com'='https://deploy0924.contoso.com:8172/msdeploy.axd'
            'deploy0924.contoso.com:8172/msdeploy.axd'='https://deploy0924.contoso.com:8172/msdeploy.axd'
            'deploy0924.contoso.com:304'='https://deploy0924.contoso.com:304/msdeploy.axd'
            's2.publish.antdir0.antares-test.contoso.net:444'='https://s2.publish.antdir0.antares-test.contoso.net:444/msdeploy.axd'
            's2.publish.antdir0.antares-test.contoso.net:443'='https://s2.publish.antdir0.antares-test.contoso.net/msdeploy.axd'
            's2.publish.antdir0.antares-test.contoso.net:80'='https://s2.publish.antdir0.antares-test.contoso.net:80/msdeploy.axd'
        }

        foreach($key in $expectedActual.Keys){
            $serviceurl = $key
            $expected = $expectedActual[$key]

            InternalNormalize-MSDeployUrl -serviceUrl $serviceUrl -serviceMethod WMSVC | Should be $expected
        }
    }

    It 'can use RemoteAgent'{
        $expectedActual = [ordered]@{
            'http://contoso'='http://contoso/MSDEPLOYAGENTSERVICE'
            'contoso'='http://contoso/MSDEPLOYAGENTSERVICE'
            'contoso.com'='http://contoso.com/MSDEPLOYAGENTSERVICE'
        }

        foreach($key in $expectedActual.Keys){
            $serviceurl = $key
            $expected = $expectedActual[$key]

            InternalNormalize-MSDeployUrl -serviceUrl $serviceUrl -serviceMethod RemoteAgent | Should be $expected
        }
    }

    It 'can use RemoteAgent old'{
        $msdeployServiceUrl = 'contoso.com'
        $expected = ('http://{0}/MSDEPLOYAGENTSERVICE' -f $msdeployServiceUrl)
        $actual = InternalNormalize-MSDeployUrl -serviceUrl $msdeployServiceUrl -serviceMethod RemoteAgent
        $actual | Should be $expected
    }
}

Describe "Execute-CommandString tests"{
    It 'executes the command'{
        $strToPrint = 'contoso'
        $commandToExec = ('echo {0}' -f $strToPrint)
        $result = (Execute-CommandString -command $commandToExec)

        $result | Should be $strToPrint
        
        $result = (Execute-CommandString $commandToExec -useInvokeExpression)
        $result | Should be $strToPrint
    }

    It 'fails when the command is invalid' {
        $strToPrint = 'contoso'
        $commandToExec = ('echodddd {0}' -f $strToPrint)
        {Execute-CommandString -command $commandToExec} | Should Throw
        {Execute-CommandString -command $commandToExec -useInvokeExpression} | Should Throw
    }

    It 'does not throw on invalid commands if ignoreExitCode is passed' {
        $strToPrint = 'contoso'
        $commandToExec = ('echodddd {0}' -f $strToPrint)
        {Execute-CommandString -command $commandToExec -ignoreErrors} | Should Not Throw
        {Execute-CommandString -command $commandToExec -ignoreErrors -useInvokeExpression} | Should Not Throw
    }

    It 'accepts a single value from the pipeline'{
        'echo contoso' | Execute-CommandString
        'echo contoso' | Execute-CommandString -useInvokeExpression
    }

    It 'accepts a multiple values from the pipeline'{
        @('echo contoso','echo contoso-u') | Execute-CommandString
        @('echo contoso','echo contoso-u') | Execute-CommandString -useInvokeExpression
    }
}

Describe 'settings tests'{
    It 'can override setting via env var 1'{
        if((Get-Module $moduleName)){ Remove-Module $moduleName -Force }
        # $global:AspNetPublishSettings
        # InternalOverrideSettingsFromEnv
        $env:PublishMSDeployUseChecksum = $true

        # InternalOverrideSettingsFromEnv
        Import-Module $modulePath -Global -DisableNameChecking | Out-Null

        $global:AspNetPublishSettings.MsdeployDefaultProperties.MSDeployUseChecksum | Should be $env:PublishMSDeployUseChecksum

        Remove-Item -Path env:PublishMSDeployUseChecksum

        Remove-Module $moduleName -Force | Out-Null
        Import-Module $modulePath -Global -DisableNameChecking | Out-Null
    }
}

Describe 'Escape-TextForRegularExpressions tests'{
    It 'will escape\'{
        $input = 'c:\temp\some\dir\here'
        $expected = 'c:\\temp\\some\\dir\\here'

        Escape-TextForRegularExpressions -text $input | Should be $expected
    }
}

Describe 'Get-PropertiesFromPublishProfile tests'{
    $script:samplepubxml01 = @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <WebPublishMethod>MSDeploy</WebPublishMethod>
    <LastUsedBuildConfiguration>Release</LastUsedBuildConfiguration>
    <LastUsedPlatform>Any CPU</LastUsedPlatform>
    <SiteUrlToLaunchAfterPublish>http://sayedhademo01.azurewebsites.net</SiteUrlToLaunchAfterPublish>
    <LaunchSiteAfterPublish>True</LaunchSiteAfterPublish>
    <ExcludeApp_Data>False</ExcludeApp_Data>
    <CompileSource>False</CompileSource>
    <UsePowerShell>True</UsePowerShell>
    <WebRoot>wwwroot</WebRoot>
    <MSDeployServiceURL>sayedhademo01.scm.azurewebsites.net:443</MSDeployServiceURL>
    <DeployIisAppPath>sayedhademo01</DeployIisAppPath>
    <RemoteSitePhysicalPath />
    <SkipExtraFilesOnServer>True</SkipExtraFilesOnServer>
    <MSDeployPublishMethod>WMSVC</MSDeployPublishMethod>
    <EnableMSDeployBackup>True</EnableMSDeployBackup>
    <UserName>$sayedhademo01</UserName>
    <_SavePWD>True</_SavePWD>
    <_DestinationType>AzureWebSite</_DestinationType>
  </PropertyGroup>
</Project>
'@
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
    It 'Can read a .pubxml file.'{
        $samplepath = 'get-propsfrompubxml\sample01.pubxml'
        Setup -File -Path $samplepath -Content $script:samplepubxml01
        $path = Join-Path $TestDrive $samplepath

        $result = Get-PropertiesFromPublishProfile $path

        $result | Should not be $null
        $result.Count | Should be 18
        $result['WebPublishMethod'] | Should be 'MSDeploy'
        $result['WebRoot'] | Should be 'wwwroot'
        $result['MSDeployPublishMethod'] | Should be 'WMSVC'
        $result['_SavePWD'] | Should be 'True'
    }

    It 'can publish to file sys with pubxml'{
        $tempdir = (Join-Path $TestDrive 'pubxmlfilesystemp01')
        New-Item -ItemType Directory -Path $tempdir
        $contents = ($script:samplepubxml01 -f $tempdir)
        $samplePath = 'get-propsfrompubxml\sample02.pubxml'
        Setup -File -Path $samplePath -Content $contents
        $path = Join-Path $TestDrive $samplePath

        #Publish-AspNet -Confirm
    }
}