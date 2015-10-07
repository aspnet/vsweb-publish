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

Describe 'MSDeploy unit tests' {
    $global:lastCommandToGetMSDeploy = $null
    [string]$mvcSourceFolder = (resolve-path (Join-Path $samplesdir 'MvcApplication'))
    [string]$mvcPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))


    Mock Print-CommandString {
        return {
            $command
        } 
    } -param { $global:lastCommandToGetMSDeploy = $command } -ModuleName 'publish-module'

    Mock Execute-CommandString {
        return {
            $command
        }
    } -ModuleName 'publish-module'


    It 'Verify computername and other basic parameters are in args to msdeploy' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\Basic01')
        
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='MSDeploy'
            'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="somepassword-here"
        }

        [string]$lastCommand = ($global:lastCommandToGetMSDeploy)
        $lastCommand.Contains("ComputerName='https://contoso.scm.azurewebsites.net/msdeploy.axd'") | Should Be $true
        $lastCommand.Contains('UserName=''$contoso''') | Should Be $true
        $lastCommand.Contains("AuthType='Basic'") | Should Be $true
        $lastCommand.Contains('-verb:sync') | Should Be $true
        $lastCommand.Contains("$mvcPackDir") | Should Be $true
    }

    It 'Default parameters in args to msdeploy' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\Basic01')
        
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='MSDeploy'
            'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="somepassword-here"
        }

        [string]$lastCommand = ($global:lastCommandToGetMSDeploy)
        $lastCommand.Contains('-usechecksum') | Should Be $false
        $lastCommand.Contains('-enableLink:contentLibExtension') | Should Be $true
        $lastCommand.Contains("-enableRule:DoNotDeleteRule") | Should Be $true
        $lastCommand.Contains("-retryAttempts:2") | Should Be $true
        $lastCommand.Contains('-disablerule:BackupRule') | Should Be $true
    }

    It 'Can publish and not pass contentLibExtension' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\Basic01')

        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='MSDeploy'
            'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="somepassword-here"
            'EnableLinkContentLibExtension'=$false
        }

        [string]$lastCommand = ($global:lastCommandToGetMSDeploy)
        $lastCommand.Contains('-usechecksum') | Should Be $false
        $lastCommand.Contains('-enableLink:contentLibExtension') | Should Not Be $true
        $lastCommand.Contains("-enableRule:DoNotDeleteRule") | Should Be $true
        $lastCommand.Contains("-retryAttempts:2") | Should Be $true
        $lastCommand.Contains('-disablerule:BackupRule') | Should Be $true
    }

    <#  
    It 'Passing whatif passes the appropriate switch' {        
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='MSDeploy'
            'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="somepassword-here"
        } -WhatIf

        [string]$lastCommand = ($global:lastCommandToGetMSDeploy -join ' ')
        $lastCommand.Contains('-whatif') | Should Be $true
    }
    #>

    It 'Can overriding webpublish with publishProperties[''WebPublishMethodOverride'']' {        
        [string]$overrideValue = 'MSDeploy'
        $global:pubMethod = $null
        
        Mock Publish-AspNetMSDeploy {
            $global:pubMethod = ($PublishProperties['WebPublishMethod'])
        } -ModuleName publish-module
        
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='FileSystem'
            'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="somepassword-here"
            'WebPublishMethodOverride'="$overrideValue" 
        }

        $global:pubMethod | Should Be $overrideValue
    }


}

Describe 'Encrypt web.config' {
    [string]$mvcSourceFolder = (resolve-path (Join-Path $samplesdir 'MvcApplication'))
    [string]$mvcPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))

    Mock Print-CommandString {
        return {
            $command
        }
    } -param { $global:lastCommandToGetMSDeploy = $command } -ModuleName 'publish-module'

    Mock Execute-CommandString {
        return {
            $command
        }
    } -ModuleName 'publish-module'

    InternalReset-AspNetPublishHandlers
    It 'Can encrypt web.config' {
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='MSDeploy'
            'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="somepassword-here"
            'EncryptWebConfig'="$true"
        }

        [string]$lastCommand = ($global:lastCommandToGetMSDeploy).ToLowerInvariant()
        $lastCommand.Contains('-EnableRule:EncryptWebConfig'.ToLowerInvariant()) | Should Be $true
    }
}

Describe 'MSDeploy App Offline' {
    [string]$mvcSourceFolder = (resolve-path (Join-Path $samplesdir 'MvcApplication'))
    [string]$mvcPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))
   
    Mock Print-CommandString {
        return {
            $command
        }
    } -param { $global:lastCommandToGetMSDeploy = $command } -ModuleName 'publish-module'

    Mock Execute-CommandString {
        return {
            $command
        }
    } -ModuleName 'publish-module'

    It 'AppOffline default' {
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='MSDeploy'
            'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="somepassword-here"
            'EnableMSDeployAppOffline'='true'
        }

        [string]$lastCommand = ($global:lastCommandToGetMSDeploy).ToLowerInvariant()
        $lastCommand.Contains('-enablerule:appoffline') | Should Be $true
        $lastCommand.Contains('appofflinetemplate') | Should Be $false
    }

    It 'AppOffline with custom file' {
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='MSDeploy'
            'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="somepassword-here"
            'EnableMSDeployAppOffline'='true'
            'AppOfflineTemplate'='offline-template.html'
        }

        [string]$lastCommand = ($global:lastCommandToGetMSDeploy).ToLowerInvariant()
        $lastCommand.Contains('-enablerule:appoffline') | Should Be $true
        $lastCommand.Contains(',appofflinetemplate="offline-template.html"') | Should Be $true
    }
}

Describe 'Get-MSDeploy tests'{
    It 'can call Get-MSDeploy and get a path to a file that exists' {
        $msdeployPath = Get-MSDeploy

        
        $msdeployPath | Should Exist
        (Get-Item $msdeployPath) -is [System.IO.FileInfo] | Should Be $true
    }
}
