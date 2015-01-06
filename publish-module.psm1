[cmdletbinding(SupportsShouldProcess=$true)]
param()

$script:AspNetPublishHandlers = @{}

$global:AspNetPublishSettings = New-Object PSObject -Property @{
    MsdeployDefaultProperties = @{
    'MSDeployUseChecksum'=$true
    'WebRoot'='wwwroot'
    'SkipExtraFilesOnServer'=$true
    'retryAttempts' = 2
    'EnableMSDeployBackup' = $false
    }
}

$global:publishModuleSettings = New-Object psobject -Property @{
    LocalInstallDir = ("${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Common7\IDE\Extensions\Microsoft\Web Tools\Publish\")
}

function Register-AspnetPublishHandler{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name,
        [Parameter(Mandatory=$true,Position=1)]
        [ScriptBlock]$handler,
        [switch]$force
    )
    process{        
        if(!($script:AspNetPublishHandlers[$name]) -or $force ){
            'Adding handler for [{0}]' -f $name | Write-Verbose
            $script:AspNetPublishHandlers[$name] = $handler
        }
        elseif(!($force)){
            'Ignoring call to Register-AspnetPublishHandler for [name={0}], because a handler with that name exists and -force was not passed.' -f $name | Write-Verbose
        }
    }
}

function Get-AspnetPublishHandler{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $name
    )
    process{
        $script:AspNetPublishHandlers[$name]
    }
}

function GetInternal-ExcludeFilesArg{
    [cmdletbinding()]
    param(
        $publishProperties
    )
    process{
        $excludeFiles = $publishProperties['ExcludeFiles']
        foreach($exclude in $excludeFiles){
            [string]$objName = $exclude['objectname']

            if([string]::IsNullOrEmpty($objName)){
                $objName = 'filePath'
            }

            [ValidateNotNullOrEmpty()]
            $excludePath = $exclude['absolutepath']

            # output the result to the return list
            ('-skip:objectName={0},absolutePath={1}' -f $objName, $excludePath)
        }
    }
}

function GetInternal-ReplacementsMSDeployArgs{
    [cmdletbinding()]
    param(
        $publishProperties
    )
    process{
        foreach($replace in ($publishProperties['Replacements'])){                
            $typeValue = $replace['type']
            if(!$typeValue){ $typeValue = 'TextFile' }
                
            $file = $replace['file']
            $match = $replace['match']
            $newValue = $replace['newValue']

            if($file -and $match -and $newValue){
                $setParam = ('-setParam:type={0},scope={1},match={2},value={3}' -f $typeValue,$file, $match,$newValue)
                'Adding setparam [{0}]' -f $setParam | Write-Verbose

                # return it
                $setParam
            }
            else{
                'Skipping replacement because its missing a required value.[file="{0}",match="{1}",newValue="{2}"]' -f $file,$match,$newValue | Write-Verbose
            }
        }       
    }
}

<#
.SYNOPSIS
Returns an array of msdeploy arguments that are used across different providers.
For example this wil handle useChecksum, appOffline, etc.
This will also add default properties if they are missing.
#>
function GetInternal-SharedMSDeployParametersFrom{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $publishProperties
    )
    process{
        $sharedArgs = New-Object psobject -Property @{
            ExtraArgs = @()
            DestFragment = ''
        }

        # add default properties if they are missing
        foreach($propName in $global:AspNetPublishSettings.MsdeployDefaultProperties.Keys){
            if($publishProperties["$propName"] -eq $null){
                $defValue = $global:AspNetPublishSettings.MsdeployDefaultProperties["$propName"]
                'Adding default property to publishProperties ["{0}"="{1}"]' -f $propName,$defValue | Write-Verbose
                $publishProperties["$propName"] = $defValue
            }
        }

        if($publishProperties['MSDeployUseChecksum'] -eq $true){
            $sharedArgs.ExtraArgs += '-usechecksum'
        }

        if($publishProperties['WebPublishMethod'] -eq 'MSDeploy'){
            $offlineArgs = GetInternal-PublishAppOfflineProperties -publishProperties $publishProperties
            $sharedArgs.ExtraArgs += $offlineArgs.AdditionalArguments
            $sharedArgs.DestFragment += $offlineArgs.DestFragment
        }

        if($publishProperties['SkipExtraFilesOnServer'] -eq $true){
            $sharedArgs.ExtraArgs += '-enableRule:DoNotDeleteRule'
        }

        if($publishProperties['retryAttempts']){
            $sharedArgs.ExtraArgs += ('-retryAttempts:{0}' -f ([int]$publishProperties['retryAttempts']))
        }

        if($publishProperties['EncryptWebConfig'] -eq $true){
            $sharedArgs.ExtraArgs += '-EnableRule:EncryptWebConfig'
        }

        if($publishProperties['EnableMSDeployBackup'] -eq $false){
            $sharedArgs.ExtraArgs += '-disablerule:BackupRule'
        }

        if(!($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))){
            $sharedArgs.ExtraArgs +='-whatif'
            # $sharedArgs.ExtraArgs +='-xml'
        }

        # add excludes
        $sharedArgs.ExtraArgs += (GetInternal-ExcludeFilesArg -publishProperties $publishProperties)
        # add replacements
        $sharedArgs.ExtraArgs += (GetInternal-ReplacementsMSDeployArgs -publishProperties $publishProperties)

        # return the args
        $sharedArgs
    }
}

<#
.SYNOPSIS
This will publish the folder based on the properties in $publishProperties

.EXAMPLE
 Publish-AspNet -packOutput $packOutput -publishProperties @{
     'WebPublishMethod'='MSDeploy'
     'MSDeployServiceURL'='sayedkdemo2.scm.azurewebsites.net:443';`
     'DeployIisAppPath'='sayedkdemo2';'Username'='$sayedkdemo2';'Password'="$env:PublishPwd"}

.EXAMPLE
Publish-AspNet -packOutput $packOutput -publishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'="$publishDest"
	}

.EXAMPLE
Publish-AspNet -packOutput $packOutput -publishProperties @{
     'WebPublishMethod'='MSDeploy'
     'MSDeployServiceURL'='sayedkdemo2.scm.azurewebsites.net:443';`
'DeployIisAppPath'='sayedkdemo2';'Username'='$sayedkdemo2';'Password'="$env:PublishPwd"
 	'ExcludeFiles'=@(
		@{'absolutepath'='wwwroot\\test.txt'},
		@{'absolutepath'='wwwroot\\_references.js'}
)} 

.EXAMPLE
Publish-AspNet -packOutput $packOutput -publishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'="$publishDest"
	'ExcludeFiles'=@(
		@{'absolutepath'='wwwroot\\test.txt'},
		@{'absolutepath'='wwwroot\\_references.js'})
	'Replacements' = @(
		@{'file'='foo.txt$';'match'='REPLACEME';'newValue'='updated2222'})
	}

Publish-AspNet -packOutput $packOutput -publishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'="$publishDest"
	'ExcludeFiles'=@(
		@{'absolutepath'='wwwroot\\test.txt'},
		@{'absolutepath'='c:\\full\\path\\ok\\as\\well\\_references.js'})
	'Replacements' = @(
		@{'file'='foo.txt$';'match'='REPLACEME';'newValue'='updated2222'})
	}

.EXAMPLE
Publish-AspNet -packOutput $packOutput -publishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'="$publishDest"
	'EnableMSDeployAppOffline'='true'
	'AppOfflineTemplate'='offline-template.html'
	'MSDeployUseChecksum'='true'
}
#>
function Publish-AspNet{
    [cmdletbinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $publishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $packOutput
    )
    process{
        if($publishProperties['WebPublishMethodOverride']){
            'Overriding publish method from $publishProperties[''WebPublishMethodOverride''] to [{0}]' -f  ($publishProperties['WebPublishMethodOverride']) | Write-Verbose
            $publishProperties['WebPublishMethod'] = $publishProperties['WebPublishMethodOverride']
        }

        $pubMethod = $publishProperties['WebPublishMethod']
        'Publishing with publish method [{0}]' -f $pubMethod | Write-Output

        # get the handler based on WebPublishMethod, and call it.
        # it seems that -whatif and -verbose are flowing through
        &(Get-AspnetPublishHandler -name $pubMethod) $publishProperties $packOutput
    }
}

function Publish-AspNetMSDeploy{
    [cmdletbinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $publishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $packOutput
    )
    process{
        if($publishProperties){
            $publishPwd = $publishProperties['Password']

            <#
            "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe" 
                -source:IisApp='C:\Users\vramak\AppData\Local\Temp\AspNetPublish\WebApplication184-93\wwwroot' 
                -dest:IisApp='vramak4',ComputerName='https://vramak4.scm.azurewebsites.net/msdeploy.axd',UserName='$vramak4',Password='<PWD>',IncludeAcls='False',AuthType='Basic' 
                -verb:sync 
                -enableRule:DoNotDeleteRule 
                -enableLink:contentLibExtension 
                -retryAttempts=2 
                -userAgent="VS14.0:PublishDialog:WTE14.0.51027.0"
            #>
            # TODO: Get wwwroot value from $publishProperties

            $sharedArgs = GetInternal-SharedMSDeployParametersFrom -publishProperties $publishProperties 

            # WebRoot is a required property which has a default
            [ValidateNotNullOrEmpty()]
            $webroot = $publishProperties['WebRoot']

            $webrootOutputFolder = (get-item (Join-Path $packOutput $webroot)).FullName
            $publishArgs = @()
            $publishArgs += ('-source:IisApp=''{0}''' -f "$webrootOutputFolder")
            $publishArgs += ('-dest:IisApp=''{0}'',ComputerName=''{1}'',UserName=''{2}'',Password=''{3}'',IncludeAcls=''False'',AuthType=''Basic''{4}' -f 
                                    $publishProperties['DeployIisAppPath'],
                                    (Get-MSDeployFullUrlFor -msdeployServiceUrl $publishProperties['MSDeployServiceURL']),
                                    $publishProperties['UserName'],
                                    $publishPwd,
                                    $sharedArgs.DestFragment)
            $publishArgs += '-verb:sync'
            $publishArgs += '-enableLink:contentLibExtension'
            $publishArgs += $sharedArgs.ExtraArgs

            'Calling msdeploy with the call {0}' -f (($publishArgs -join ' ').Replace($publishPwd,'{PASSWORD-REMOVED-FROM-LOG}')) | Write-Output
            'Calling msdeploy with the call {0}' -f (($publishArgs -join ' ').Replace($publishPwd,'{PASSWORD-REMOVED-FROM-LOG}')) | Write-Verbose
            & (Get-MSDeploy) $publishArgs
        }
        else{
            throw 'publishProperties is empty, cannot publish'
        }
    }
}

<#
.SYNOPSIS
If the passed in $publishProperties has values for appOffline the
needed arguments will be in the return object. If there is no such configuraion
then nothing is returned.
#>
function GetInternal-PublishAppOfflineProperties{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $publishProperties
    )
    process{
        $extraArg = '';
        $destFragment = ''
        if($publishProperties['EnableMSDeployAppOffline'] -eq $true){
            $extraArg = '-enablerule:AppOffline'

            $appOfflineTemplate = $publishProperties['AppOfflineTemplate']
            if($appOfflineTemplate){
                $destFragment = (',appOfflineTemplate="{0}"' -f $appOfflineTemplate)
            }
        }
        # return an object with both the properties that need to be in the command.
        New-Object psobject -Property @{
            AdditionalArguments = $extraArg
            DestFragment = $destFragment
        }
    }
}

function Publish-AspNetFileSystem{
    [cmdletbinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $publishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $packOutput
    )
    process{
        $pubOut = $publishProperties['publishUrl']
        'Publishing files to {0}' -f $pubOut | Write-Output

        # we can use msdeploy.exe because it supports incremental publish/skips/replacements/etc
        # msdeploy.exe -verb:sync -source:contentPath='C:\srcpath' -dest:contentPath='c:\destpath'
        
        $sharedArgs = GetInternal-SharedMSDeployParametersFrom -publishProperties $publishProperties

        $publishArgs = @()
        $publishArgs += ('-source:contentPath=''{0}''' -f "$packOutput")
        $publishArgs += ('-dest:contentPath=''{0}''{1}' -f "$pubOut",$sharedArgs.DestFragment)
        $publishArgs += '-verb:sync'
        $publishArgs += $sharedArgs.ExtraArgs

        'Calling msdeploy to publish to file system with the command: [{0} {1}]' -f (Get-MSDeploy),($publishArgs -join ' ') | Write-Output
        & (Get-MSDeploy) $publishArgs
    }
}

function Get-MSDeploy {
    [cmdletbinding()]
    param()
    process{
        $msdInstallLoc = $env:MSDeployPath
        if(!($msdInstallLoc)) {
        # TODO: Get this from HKLM SOFTWARE\Microsoft\IIS Extensions\MSDeploy See MSDeploy VS task for implementation
            $progFilesFolder = (Get-ChildItem env:"ProgramFiles").Value
            $msdLocToCheck = @()
            $msdLocToCheck += ("{0}\IIS\Microsoft Web Deploy V3\msdeploy.exe" -f $progFilesFolder)
            $msdLocToCheck += ("{0}\IIS\Microsoft Web Deploy V2\msdeploy.exe" -f $progFilesFolder)
            $msdLocToCheck += ("{0}\IIS\Microsoft Web Deploy\msdeploy.exe" -f $progFilesFolder)
           
            foreach($locToCheck in $msdLocToCheck) {
                "Looking for msdeploy.exe at [{0}]" -f $locToCheck | Write-Verbose | Out-Null
                if(Test-Path $locToCheck) {
                    $msdInstallLoc = $locToCheck
                    break;
                }
            }        
        }
    
        if(!$msdInstallLoc){
            throw "Unable to find msdeploy.exe, please install it and try again"
        }
    
        "Found msdeploy.exe at [{0}]" -f $msdInstallLoc | Write-Verbose | Out-Null

        return $msdInstallLoc
    }
}

function Get-MSDeployFullUrlFor{
    [cmdletbinding()]
    param($msdeployServiceUrl)
    process{
        # Convert sayedkdemo.scm.azurewebsites.net:443 to https://sayedkdemo.scm.azurewebsites.net/msdeploy.axd
        # TODO: This needs to be improved, it only works with Azure Websites. We have code for this.
        'https://{0}/msdeploy.axd' -f $msdeployServiceUrl.TrimEnd(':443')
    }
}

function Enable-PsNuGet{
    [cmdletbinding()]
    param($toolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\psnuget\",
        $psNuGetDownloadUrl = 'https://raw.githubusercontent.com/sayedihashimi/publish-module/master/getnuget.psm1')
    process{
        # try to load from local install first
        if(!(get-module 'getnuget')){
            $localpsnugetpath = Join-Path $global:publishModuleSettings.LocalInstallDir 'getnuget.psm1'
            if(Test-Path $localpsnugetpath){
                'importing module [psnuget="{0}"] from local install dir' -f $localpsnugetpath | Write-Output
                Import-Module $localpsnugetpath -DisableNameChecking -Force -Scope Global
            }
        }

        if(!(get-module 'getnuget')){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory }

            $expectedPath = (Join-Path ($toolsDir) 'getnuget.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $psNuGetDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($psNuGetDownloadUrl, $expectedPath)
            }
        
            if(!$expectedPath){throw ('Unable to download getnuget.psm1')}

            'importing module [{0}]' -f $expectedPath | Write-Output
            Import-Module $expectedPath -DisableNameChecking -Force -Scope Global
        }
    }
}

function Get-VisualStudio2015InstallPath{
    [cmdletbinding()]
    param()
    process{
        $keysToCheck = @('hklm:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\14.0','hklm:\SOFTWARE\Microsoft\VisualStudio\14.0')
        [string]$vsInstallPath=$null

        foreach($keyToCheck in $keysToCheck){
            if(Test-Path $keyToCheck){
                $vsInstallPath = (Get-itemproperty $keyToCheck -Name InstallDir | select -ExpandProperty InstallDir)
            }

            if($vsInstallPath){
                break;
            }
        }

        $vsInstallPath
    }
}

function InternalRegister-AspNetKnownPublishHandlers{
    [cmdletbinding()]
    param()
    process{
        'Registering MSDeploy handler' | Write-Verbose
        Register-AspnetPublishHandler -name 'MSDeploy' -force -handler {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            Publish-AspNetMSDeploy -publishProperties $publishProperties -packOutput $packOutput
        }

        'Registering FileSystem handler' | Write-Verbose
        Register-AspnetPublishHandler -name 'FileSystem' -force -handler {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )
    
            Publish-AspNetFileSystem -publishProperties $publishProperties -packOutput $packOutput
        }
    }
}

<#
.SYNOPSIS
    Used for testing purposes only.
#>
function InternalReset-AspNetPublishHandlers{
    [cmdletbinding()]
    param()
    process{
        $script:AspNetPublishHandlers = @{}
        InternalRegister-AspNetKnownPublishHandlers
    }
}

Export-ModuleMember -function Get-*,Publish-*,Register-*,Enable-*
if($env:IsDeveloperMachine){
    # you can set the env var to expose all functions to importer. easy for development.
    # this is required for executing pester test cases, it's set by build.ps1
    Export-ModuleMember -function *
}

# register the handlers so that Publish-AspNet can be called
InternalRegister-AspNetKnownPublishHandlers

Enable-PsNuGet
