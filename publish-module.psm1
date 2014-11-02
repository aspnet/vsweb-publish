[cmdletbinding()]
param()

function AspNet-Publish{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $PublishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $OutputPath
    )
    process{
        $pubMethod = $PublishProperties['WebPublishMethod']
        'Publishing with publish method [{0}]' -f $pubMethod | Write-Output
        # figure out which of the impl method to call for the specific publish method
        switch ($pubMethod){
            'MSDeploy' {AspNet-PublishMSDeploy -PublishProperties $PublishProperties -OutputPath $OutputPath}
            'FileSystem' {AspNet-PublishFileSystem -PublishProperties $PublishProperties -OutputPath $OutputPath}
            default { throw ('Unknown value for WebPublishMethod [{0}]' -f $pubMethod)}
        }
    }
}

function AspNet-PublishMSDeploy{
    [cmdletbinding()]
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
            if(!$publishPwd){
                throw 'Publish password is not found please set $env:PublishPassword'
            }

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
            # TODO: Should we pass this property in?
            $publishArgs += '-enableRule:DoNotDeleteRule'
            $publishArgs += '-enableLink:contentLibExtension'
            $publishArgs += '-retryAttempts=2'

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
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $PublishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $OutputPath
    )
    process{
        $pubOut = $PublishProperties['publishUrl']
        'Publishing files to {0}' -f $pubOut | Write-Output
        # do a file system copy, if there is any skips we have to take care of it in an 
        Get-ChildItem -Path $OutputPath | % {
          Copy-Item $_.fullname "$pubOut" -Recurse -Force
        }
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