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
        Get-AspnetPublishHandler -name 'Docker' | Should Not Be $null
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

Describe 'Get-MSDeployFullUrlFor tests'{
    # TODO: When we add support for all msdeploy sites we should beef up these test cases
    It 'Returns the correct value for Azure WebSites' {
        # 'https://{0}/msdeploy.axd' -f $msdeployServiceUrl.TrimEnd(':443')
        $msdeployServiceUrl = 'sayedkdemo2.scm.azurewebsites.net:443'
        $expected = ('https://{0}/msdeploy.axd' -f $msdeployServiceUrl.TrimEnd(':443'))

        Get-MSDeployFullUrlFor -msdeployServiceUrl $msdeployServiceUrl | Should Be $expected
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

