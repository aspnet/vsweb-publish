[cmdletbinding(SupportsShouldProcess=$true)]
param()

$script:AspNetPublishHandlers = @{}

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
        if(!($script:AspNetPublishHandlers[$name])){
            throw ('Aspnet publish handler not found for [{0}]' -f $name)
        }
        else{
            $script:AspNetPublishHandlers[$name]
        }
    }
}

function InternalGet-ExcludeFilesArg{
    [cmdletbinding()]
    param(
        $publishProperties
    )
    process{
        if($publishProperties -and ($publishProperties['ExcludeFiles'])){
            foreach($exclude in ($publishProperties['ExcludeFiles'])){
                $excludePath = $exclude['Filepath']

                # output the result to the return list
                ('-skip:objectName=filePath,absolutePath={0}$' -f $excludePath)
            }            
        }
    }
}

function InternalGet-ReplacementsMSDeployArgs{
    [cmdletbinding()]
    param(
        $publishProperties
    )
    process{
        if($publishProperties -and ($publishProperties['Replacements'])){
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
                    'Skipping replacement because its missing a required value.' | Write-Verbose
                }
            }
        }        
    }
}

<#
.SYNOPSIS
This will publish the folder based on the properties in $publishProperties

.EXAMPLE
 Aspnet-Publish -OutputPath $packOutput -PublishProperties @{
     'WebPublishMethod'='MSDeploy'
     'MSDeployServiceURL'='sayedkdemo2.scm.azurewebsites.net:443';`
'DeployIisAppPath'='sayedkdemo2';'Username'='$sayedkdemo2';'Password'="$env:PublishPwd"} -Verbose

.EXAMPLE
Aspnet-Publish -OutputPath $packOutput -PublishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'="$publishDest"
	}

.EXAMPLE
Aspnet-Publish -OutputPath $packOutput -PublishProperties @{
     'WebPublishMethod'='MSDeploy'
     'MSDeployServiceURL'='sayedkdemo2.scm.azurewebsites.net:443';`
'DeployIisAppPath'='sayedkdemo2';'Username'='$sayedkdemo2';'Password'="$env:PublishPwd"
 	'ExcludeFiles'=@(
		@{'Filepath'='wwwroot\\test.txt'},
		@{'Filepath'='wwwroot\\_references.js'}
)} 

.EXAMPLE
Aspnet-Publish -OutputPath $packOutput -PublishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'="$publishDest"
	'ExcludeFiles'=@(
		@{'Filepath'='wwwroot\\test.txt'},
		@{'Filepath'='wwwroot\\_references.js'})
	'Replacements' = @(
		@{'file'='foo.txt$';'match'='REPLACEME';'newValue'='updated2222'})
	}
#>
function AspNet-Publish{
    [cmdletbinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $PublishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $OutputPath
    )
    process{
        $pubMethod = $PublishProperties['WebPublishMethod']
        'Publishing with publish method [{0}]' -f $pubMethod | Write-Output

        # get the handler based on WebPublishMethod, and call it.
        # it seems that -whatif and -verbose are flowing through
        &(Get-AspnetPublishHandler -name $pubMethod) $PublishProperties $OutputPath
    }
}

function AspNet-PublishMSDeploy{
    [cmdletbinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $PublishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $OutputPath
    )
    process{
        # call msdeploy.exe to start the publish process

        if($PublishProperties){
            # TODO: Get passwod from $PublishProperties
            $publishPwd = $PublishProperties['Password']

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
            # TODO: Get wwwroot value from $PublishProperties
            $webrootOutputFolder = (get-item (Join-Path $OutputPath 'wwwroot')).FullName
            $publishArgs = @()
            $publishArgs += ('-source:IisApp=''{0}''' -f "$webrootOutputFolder")
            $publishArgs += ('-dest:IisApp=''{0}'',ComputerName=''{1}'',UserName=''{2}'',Password=''{3}'',IncludeAcls=''False'',AuthType=''Basic''' -f 
                                    $PublishProperties['DeployIisAppPath'],
                                    (Get-MSDeployFullUrlFor -msdeployServiceUrl $PublishProperties['MSDeployServiceURL']),
                                    $PublishProperties['UserName'],
                                    $publishPwd)
            $publishArgs += '-verb:sync'
            # TODO: get rules from $PublishProperties? We should have good defaults.
            $publishArgs += '-enableRule:DoNotDeleteRule'
            $publishArgs += '-enableLink:contentLibExtension'
            # TODO: Override from $PublishProperties
            $publishArgs += '-retryAttempts=2'
            # $publishArgs += '-useChecksum'
            $publishArgs += '-disablerule:BackupRule'

            $whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))
            if($whatifpassed){
                $publishArgs+='-whatif'
                $publishArgs+='-xml'
            }

            # add excludes
            $publishArgs += (InternalGet-ExcludeFilesArg -publishProperties $PublishProperties)
            # add replacements
            $publishArgs += (InternalGet-ReplacementsMSDeployArgs -publishProperties $PublishProperties)

            'Calling msdeploy with the call {0}' -f (($publishArgs -join ' ').Replace($publishPwd,'{PASSWORD-REMOVED-FROM-LOG}')) | Write-Verbose
            & (Get-MSDeploy) $publishArgs
        }
        else{
            throw 'PublishProperties is empty, cannot publish'
        }
    }
}

function AspNet-PublishFileSystem{
    [cmdletbinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $PublishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $OutputPath
    )
    process{
        $pubOut = $PublishProperties['publishUrl']
        'Publishing files to {0}' -f $pubOut | Write-Output

        # we can use msdeploy.exe because it supports incremental publish/skips/replacements/etc
        # msdeploy.exe -verb:sync -source:contentPath='C:\srcpath' -dest:contentPath='c:\destpath'
        
        $publishArgs = @()
        $publishArgs += ('-source:contentPath=''{0}''' -f "$OutputPath")
        $publishArgs += ('-dest:contentPath=''{0}''' -f "$pubOut")
        $publishArgs += '-verb:sync'
        $publishArgs += '-useChecksum'
        $publishArgs += '-retryAttempts=2'
        $publishArgs += '-disablerule:BackupRule'

        $whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))
        if($whatifpassed){
            $publishArgs += '-whatif'
            $publishArgs += '-xml'
        }

        # add excludes
        $publishArgs += (InternalGet-ExcludeFilesArg -publishProperties $PublishProperties)
        # add replacements
        $publishArgs += (InternalGet-ReplacementsMSDeployArgs -publishProperties $PublishProperties)

        'Calling msdeploy to publish to file system with the command: [{0} {1}]' -f (Get-MSDeploy),($publishArgs -join ' ') | Write-Verbose
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

Export-ModuleMember -function Get-*,AspNet-*

##############################################
# register the handlers
##############################################
'Registering MSDeploy handler' | Write-Verbose
Register-AspnetPublishHandler -name 'MSDeploy' -force -handler { 
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $PublishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $OutputPath
    )
    
    AspNet-PublishMSDeploy -PublishProperties $PublishProperties -OutputPath $OutputPath
}

'Registering FileSystem handler' | Write-Verbose
Register-AspnetPublishHandler -name 'FileSystem' -handler {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $PublishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $OutputPath
    )
    
    AspNet-PublishFileSystem -PublishProperties $PublishProperties -OutputPath $OutputPath
}
