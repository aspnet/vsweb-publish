[cmdletbinding(SupportsShouldProcess=$true)]
param()

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
        $whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))
        # figure out which of the impl method to call for the specific publish method
        switch ($pubMethod){
            'MSDeploy' {AspNet-PublishMSDeploy -PublishProperties $PublishProperties -OutputPath $OutputPath -WhatIf:$whatifpassed}
            'FileSystem' {AspNet-PublishFileSystem -PublishProperties $PublishProperties -OutputPath $OutputPath -WhatIf:$whatifpassed}
            default { throw ('Unknown value for WebPublishMethod [{0}]' -f $pubMethod)}
        }
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
            $publishArgs += '-useChecksum'

            $whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))
            if($whatifpassed){
                $publishArgs+='-whatif'
                $publishArgs+='-xml'
            }

            # see if there are any skips in $PublishProperties.
            $excludeFiles = $PublishProperties['ExcludeFiles']
            if($excludeFiles){
                foreach($exclude in $excludeFiles){
                    $excludePath = $exclude['Filepath']
                    $publishArgs += ('-skip:objectName=filePath,absolutePath={0}$' -f $excludePath)
                }
            }

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
        # do a file system copy
        # TODO: Add exclude statements based on skips from $PublishProperties
        # TODO: Add support for retryAttempts?

        $excludeList = @()
        if($PublishProperties['ExcludeFiles']){
            foreach($exclude in $PublishProperties['ExcludeFiles']){
                $excludePath = $exclude['Filepath']
                $excludeList += $excludePath
            }
        }
        
        'exclude list: [{0}]' -f ($excludeList -join (',')) | Write-Verbose

        $whatifpassed = !($PSCmdlet.ShouldProcess($env:COMPUTERNAME,"publish"))

        # we can use msdeploy.exe because it supports incremental publish/skips/replacements/etc
        # msdeploy.exe -verb:sync -source:contentPath='C:\srcpath' -dest:contentPath='c:\destpath'
        
        $publishArgs = @()
        $publishArgs += ('-source:contentPath=''{0}''' -f "$OutputPath")
        $publishArgs += ('-dest:contentPath=''{0}''' -f "$pubOut")
        $publishArgs += '-verb:sync'
        $publishArgs += '-useChecksum'

        if($whatifpassed){
            $publishArgs += '-whatif'
            $publishArgs += '-xml'
        }

        # see if there are any skips in $PublishProperties.
        $excludeFiles = $PublishProperties['ExcludeFiles']
        if($excludeFiles){
            foreach($exclude in $excludeFiles){
                $excludePath = $exclude['Filepath']
                $publishArgs += ('-skip:objectName=filePath,absolutePath={0}$' -f $excludePath)
            }
        }

        'Calling msdeploy to publish to file system wiht the command: [{0} {1}]' -f (Get-MSDeploy),($publishArgs -join '') | Write-Verbose
        & (Get-MSDeploy) $publishArgs
        #$webrootOutputFolder = (get-item (Join-Path $OutputPath 'wwwroot')).FullName
        #Get-ChildItem -Path $outputpath -Exclude $excludeList | % {
        #  Copy-Item $_.fullname "$pubOut" -Recurse -Force -WhatIf:$whatifpassed
        #}
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
