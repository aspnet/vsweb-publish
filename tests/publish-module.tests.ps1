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
        Register-AspnetPublishHandler -name 'customhandler' -handler {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            'Inside custom handler here' | Write-Output
        }

        Get-AspnetPublishHandler -name 'customhandler' | Should Not Be Null
        InternalReset-AspNetPublishHandlers
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
        (Get-AspnetPublishHandler -name 'customhandler2') | Should be $null
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

    It 'Returns null for unregistered names' {
        Get-AspnetPublishHandler -name 'some-unregistered-name' | Should Be $null
    }
}

Describe 'Get-MSDeploy tests' {
    It 'Returns a value' {
        Get-MSDeploy | Should Not Be $null
    }   
}

Describe 'Get-MSDeployFullUrlFor tests'{
    # TODO: When we add support for all msdeploy sites we should beef up these test cases
    It 'Returns the correct value for Azure WebSites' {
        # 'https://{0}/msdeploy.axd' -f $msdeployServiceUrl.TrimEnd(':443')
        $msdeployServiceUrl = 'sayedkdemo2.scm.azurewebsites.net:443'
        $expected = ('https://{0}/msdeploy.axd' -f $msdeployServiceUrl.TrimEnd(':443'))

        Get-MSDeployFullUrlFor -msdeployServiceUrl $msdeployServiceUrl | Should Be $expected
    }
}


