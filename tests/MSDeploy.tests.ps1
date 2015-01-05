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
    $global:lastArgsToGetMSDeploy = $null
    [string]$mvcSourceFolder = (resolve-path (Join-Path $samplesdir 'MvcApplication'))
    [string]$mvcPackDir = (resolve-path (Join-Path $samplesdir 'MvcApplication-packOutput'))

    Mock Get-MSDeploy {
        return {
            $global:lastArgsToGetMSDeploy = ($args[0])
            
            # just return what was called so that it can be inspected
            $args[0]
        }
    } -ModuleName 'publish-module'

    It 'Verify computername and other basic parameters are in args to msdeploy' {
        $publishDest = (Join-Path $TestDrive 'e2eFileSystem\Basic01')
        
        Publish-AspNet -packOutput $mvcPackDir -publishProperties @{
            'WebPublishMethod'='MSDeploy'
            'MSDeployServiceURL'='sayedkdemo2.scm.azurewebsites.net:443';`
            'DeployIisAppPath'='sayedkdemo2';'Username'='$sayedkdemo2';'Password'="somepassword-here"
        }

        [string]$lastCommand = ($global:lastArgsToGetMSDeploy -join ' ')
        $lastCommand.Contains("ComputerName='https://sayedkdemo2.scm.azurewebsites.net/msdeploy.axd'") | Should Be $true
        $lastCommand.Contains('UserName=''$sayedkdemo2''') | Should Be $true
        $lastCommand.Contains("Password='somepassword-here'") | Should Be $true
        $lastCommand.Contains("AuthType='Basic'") | Should Be $true
        $lastCommand.Contains("$mvcPackDir") | Should Be $true
    }
}