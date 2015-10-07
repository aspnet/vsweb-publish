# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

[cmdletbinding(SupportsShouldProcess=$true)]
param()

$script:AspNetPublishHandlers = @{}

<#
These settings can be overridden with environment variables.
The name of the environment variable should use "Publish" as a
prefix and the names below. For example:

    $env:PublishMSDeployUseChecksum = $true
    $env:PublishWwwRootOut = 'customwwwroot'
#>
$global:AspNetPublishSettings = New-Object -TypeName PSCustomObject @{
    MsdeployDefaultProperties = @{
        'MSDeployUseChecksum'=$false
        'WwwRootOut'='wwwroot'
        'SkipExtraFilesOnServer'=$true
        'retryAttempts' = 2
        'EnableMSDeployBackup' = $false
        'DeleteExistingFiles' = $false
        'AllowUntrustedCertificate'= $false
        'MSDeployPackageContentFoldername'='website\'
        'EnableLinkContentLibExtension'=$true
    }
}

function InternalOverrideSettingsFromEnv{
    [cmdletbinding()]
    param(
        [Parameter(Position=0)]
        [object[]]$settings = ($global:AspNetPublishSettings,$global:AspNetPublishSettings.MsdeployDefaultProperties),

        [Parameter(Position=1)]
        [string]$prefix = 'Publish'
    )
    process{
        foreach($settingsObj in $settings){
            if($settingsObj -eq $null){
                continue
            }

            $settingNames = $null
            if($settingsObj -is [hashtable]){
                $settingNames = $settingsObj.Keys
            }
            else{
                $settingNames = ($settingsObj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)

            }

            foreach($name in ($settingNames.Clone())){
                $fullname = ('{0}{1}' -f $prefix,$name)
                if(Test-Path "env:$fullname"){
                    $settingsObj.$name = ((get-childitem "env:$fullname").Value)
                }
            }
        }
    }
}

InternalOverrideSettingsFromEnv -prefix 'Publish' -settings $global:AspNetPublishSettings,$global:AspNetPublishSettings.MsdeployDefaultProperties

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
        $foundHandler = $script:AspNetPublishHandlers[$name]

        if(!$foundHandler){
            throw ('AspnetPublishHandler with name "{0}" was not found' -f $name)
        }

        $foundHandler
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
            if($exclude){
                [string]$objName = $exclude['objectname']

                if([string]::IsNullOrEmpty($objName)){
                    $objName = 'filePath'
                }

                $excludePath = $exclude['absolutepath']

                # output the result to the return list
                ('-skip:objectName={0},absolutePath=''{1}''' -f $objName, $excludePath)
            }	
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
            if($replace){           
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
            
            if($publishProperties['SkipExtraFilesOnServer'] -eq $true){
                $sharedArgs.ExtraArgs += '-enableRule:DoNotDeleteRule'
            }
        }

        if($publishProperties['WebPublishMethod'] -eq 'FileSystem'){
            if($publishProperties['DeleteExistingFiles'] -eq $false){
                $sharedArgs.ExtraArgs += '-enableRule:DoNotDeleteRule'
            }
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

        if($publishProperties['AllowUntrustedCertificate'] -eq $true){
            $sharedArgs.ExtraArgs += '-allowUntrusted'
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

.PARAMETER publishProperties
This is a hashtable containing the publish properties. See the examples here for more info on how to use this parameter.

.PARAMETER packOutput
The folder path to the output of the dnu publish command. This folder contains the files
that will be published.

.PARAMETER pubProfilePath
Path to a publish profile (.pubxml file) to import publish properties from. If the same property exists in
publishProperties and the publish profile then publishProperties will win.

.EXAMPLE
 Publish-AspNet -packOutput $packOutput -publishProperties @{
     'WebPublishMethod'='MSDeploy'
     'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
     'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="$env:PublishPwd"}

.EXAMPLE
Publish-AspNet -packOutput $packOutput -publishProperties @{
    'WebPublishMethod'='FileSystem'
    'publishUrl'="$publishDest"
    }

.EXAMPLE
Publish-AspNet -packOutput $packOutput -publishProperties @{
     'WebPublishMethod'='MSDeploy'
     'MSDeployServiceURL'='contoso.scm.azurewebsites.net:443';`
'DeployIisAppPath'='contoso';'Username'='$contoso';'Password'="$env:PublishPwd"
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
        @{'file'='test.txt$';'match'='REPLACEME';'newValue'='updatedValue'})
    }

Publish-AspNet -packOutput $packOutput -publishProperties @{
    'WebPublishMethod'='FileSystem'
    'publishUrl'="$publishDest"
    'ExcludeFiles'=@(
        @{'absolutepath'='wwwroot\\test.txt'},
        @{'absolutepath'='c:\\full\\path\\ok\\as\\well\\_references.js'})
    'Replacements' = @(
        @{'file'='test.txt$';'match'='REPLACEME';'newValue'='updatedValue'})
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
        [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [hashtable]$publishProperties = @{},

        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        [System.IO.FileInfo]$packOutput,

        [Parameter(Position=2,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [ValidateScript({Test-Path $_})]
        [System.IO.FileInfo]$pubProfilePath
    )
    process{
        if($publishProperties['WebPublishMethodOverride']){
            'Overriding publish method from $publishProperties[''WebPublishMethodOverride''] to [{0}]' -f  ($publishProperties['WebPublishMethodOverride']) | Write-Verbose
            $publishProperties['WebPublishMethod'] = $publishProperties['WebPublishMethodOverride']
        }

        if(-not [string]::IsNullOrWhiteSpace($pubProfilePath)){
            $profileProperties = Get-PropertiesFromPublishProfile -filepath $pubProfilePath
            foreach($key in $profileProperties.Keys){
                if(-not ($publishProperties.ContainsKey($key))){
                    'Adding properties from publish profile [''{0}''=''{1}'']' -f $key,$profileProperties[$key] | Write-Verbose
                    $publishProperties.Add($key,$profileProperties[$key])
                }
            }
        }

        if(!([System.IO.Path]::IsPathRooted($packOutput))){
            $packOutput = [System.IO.Path]::GetFullPath((Join-Path $pwd $packOutput))
        }

        $pubMethod = $publishProperties['WebPublishMethod']
        'Publishing with publish method [{0}]' -f $pubMethod | Write-Output

        # get the handler based on WebPublishMethod, and call it.
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
                -source:IisApp='C:\Users\contoso\AppData\Local\Temp\AspNetPublish\WebApplication1\wwwroot' 
                -dest:IisApp='vramak4',ComputerName='https://contoso.scm.azurewebsites.net/msdeploy.axd',UserName='$contoso',Password='<PWD>',IncludeAcls='False',AuthType='Basic' 
                -verb:sync 
                -enableRule:DoNotDeleteRule 
                -enableLink:contentLibExtension 
                -retryAttempts=2 
                -userAgent="VS14.0:PublishDialog:WTE14.0.51027.0"
            #>

            $sharedArgs = GetInternal-SharedMSDeployParametersFrom -publishProperties $publishProperties 

            $serviceMethod = 'WMSVC'
            if(-not [string]::IsNullOrWhiteSpace($publishProperties['MSDeployPublishMethod'])){
                $serviceMethod = $publishProperties['MSDeployPublishMethod']
            }

            # WwwRootOut is a required property which has a default
            $webroot = $publishProperties['WwwRootOut']

            $webrootOutputFolder = (get-item (Join-Path $packOutput $webroot)).FullName
            $publishArgs = @()
            $publishArgs += ('-source:IisApp=''{0}''' -f "$webrootOutputFolder")
            $publishArgs += ('-dest:IisApp=''{0}'',ComputerName=''{1}'',UserName=''{2}'',Password=''{3}'',IncludeAcls=''False'',AuthType=''Basic''{4}' -f 
                                    $publishProperties['DeployIisAppPath'],
                                    (InternalNormalize-MSDeployUrl -serviceUrl $publishProperties['MSDeployServiceURL'] -serviceMethod $serviceMethod),
                                    $publishProperties['UserName'],
                                    $publishPwd,
                                    $sharedArgs.DestFragment)
            $publishArgs += '-verb:sync'
            $publishArgs += $sharedArgs.ExtraArgs

            [bool]$addContentLib = $true
            if( ($publishProperties['EnableLinkContentLibExtension'] -ne $null) -and (-not ([string]::IsNullOrWhiteSpace($publishProperties['EnableLinkContentLibExtension'])))){
                $addContentLib = $publishProperties['EnableLinkContentLibExtension']
            }

            if($addContentLib){
                $publishArgs += '-enableLink:contentLibExtension'
            }

            $command = '"{0}" {1}' -f (Get-MSDeploy),($publishArgs -join ' ')
            
            if (! [String]::IsNullOrEmpty($publishPwd)) {
            $command.Replace($publishPwd,'{PASSWORD-REMOVED-FROM-LOG}') | Print-CommandString
            }
            Execute-Command -exePath (Get-MSDeploy) -arguments ($publishArgs -join ' ')
        }
        else{
            throw 'publishProperties is empty, cannot publish'
        }
    }
}

function Escape-TextForRegularExpressions{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$text
    )
    process{
        [regex]::Escape($text)
    }
}

function Publish-AspNetMSDeployPackage{
    [cmdletbinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $publishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $packOutput
    )
    process{
        if($publishProperties){
            $packageDestFilepah = $publishProperties['DesktopBuildPackageLocation']

            if(!$packageDestFilepah){
                throw ('The package destination property (DesktopBuildPackageLocation) was not found in the publish properties')
            }

            if(!([System.IO.Path]::IsPathRooted($packageDestFilepah))){
                $packageDestFilepah = [System.IO.Path]::GetFullPath((Join-Path $pwd $packageDestFilepah))
            }

            # if the dir doesn't exist create it
            $pkgDir = ((new-object -typename System.IO.FileInfo($packageDestFilepah)).Directory)
            if(!($pkgDir.Exists)) {
                $pkgDir.Create() | Out-Null
            }

            <#
            "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe" 
                -source:IisApp='C:\Users\contoso\AppData\Local\Temp\AspNetPublish\WebApplication1\wwwroot' 
                -dest:package=c:\temp\path\contosoweb.zip
                -verb:sync 
                -enableRule:DoNotDeleteRule 
                -enableLink:contentLibExtension 
                -retryAttempts=2 
            #>

            $sharedArgs = GetInternal-SharedMSDeployParametersFrom -publishProperties $publishProperties 

            # WwwRootOut is a required property which has a default
            $webroot = $publishProperties['WwwRootOut']

            $webrootOutputFolder = (get-item (Join-Path $packOutput $webroot)).FullName
            $publishArgs = @()
            $publishArgs += ('-source:IisApp=''{0}''' -f "$webrootOutputFolder")
            $publishArgs += ('-dest:package=''{0}''' -f $packageDestFilepah)
            $publishArgs += '-verb:sync'
            $publishArgs += '-enableLink:contentLibExtension'
            $packageContentFolder = $publishProperties['MSDeployPackageContentFoldername']
            if(!$packageContentFolder){ $packageContentFolder = 'website' }
            $publishArgs += ('-replace:match=''{0}'',replace=''{1}''' -f (Escape-TextForRegularExpressions $packOutput), $packageContentFolder )
            $publishArgs += $sharedArgs.ExtraArgs
            
            $command = '"{0}" {1}' -f (Get-MSDeploy),($publishArgs -join ' ')
            $command | Print-CommandString
            Execute-Command -exePath (Get-MSDeploy) -arguments ($publishArgs -join ' ')
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
        
        if([string]::IsNullOrWhiteSpace($pubOut)){
            throw ('publishUrl is a required property for FileSystem publish but it was empty.')
        }

        # if it's a relative path then update it to a full path
        if(!([System.IO.Path]::IsPathRooted($pubOut))){
            $pubOut = [System.IO.Path]::GetFullPath((Join-Path $pwd $pubOut))
            $publishProperties['publishUrl'] = "$pubOut"
        }

        'Publishing files to {0}' -f $pubOut | Write-Output

        # we use msdeploy.exe because it supports incremental publish/skips/replacements/etc
        # msdeploy.exe -verb:sync -source:contentPath='C:\srcpath' -dest:contentPath='c:\destpath'
        
        $sharedArgs = GetInternal-SharedMSDeployParametersFrom -publishProperties $publishProperties

        $publishArgs = @()
        $publishArgs += ('-source:contentPath=''{0}''' -f "$packOutput")
        $publishArgs += ('-dest:contentPath=''{0}''{1}' -f "$pubOut",$sharedArgs.DestFragment)
        $publishArgs += '-verb:sync'
        $publishArgs += $sharedArgs.ExtraArgs

        $command = '"{0}" {1}' -f (Get-MSDeploy),($publishArgs -join ' ')
        $command | Print-CommandString
        Execute-Command -exePath (Get-MSDeploy) -arguments ($publishArgs -join ' ')
    }
}

<#
.SYNOPSIS
    This can be used to read a publish profile to extract the property values into a hashtable.

.PARAMETER filepath
    Path to the publish profile to get the properties from. Currenlty this only supports reading
    .pubxml files.

.EXAMPLE
    Get-PropertiesFromPublishProfile -filepath c:\projects\publish\devpublish.pubxml
#>
function Get-PropertiesFromPublishProfile{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateScript({Test-Path $_})]
        [System.IO.FileInfo]$filepath
    )
    begin{
        Add-Type -AssemblyName System.Core
        Add-Type -AssemblyName Microsoft.Build
    }
    process{
        'Reading publish properties from profile [{0}]' -f $filepath | Write-Verbose
        # use MSBuild to get the project and read properties
        $projectCollection = (New-Object Microsoft.Build.Evaluation.ProjectCollection)
        $project = ([Microsoft.Build.Construction.ProjectRootElement]::Open([string]$filepath.Fullname, $projectCollection))

        $properties = @{}
        foreach($property in $project.Properties){
            $properties[$property.Name]=$property.Value
        }

        $properties
    }
}

function Print-CommandString{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        $command
    )
    process{
        'Executing command [{0}]' -f $command | Write-Output
    }
}

function Execute-CommandString{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [string[]]$command,
        
        [switch]
        $useInvokeExpression,

        [switch]
        $ignoreErrors
    )
    process{
        foreach($cmdToExec in $command){
            'Executing command [{0}]' -f $cmdToExec | Write-Verbose
            if($useInvokeExpression){
                try {
                    Invoke-Expression -Command $cmdToExec
                }
                catch {
                    if(-not $ignoreErrors){
                        $msg = ('The command [{0}] exited with exception [{1}]' -f $cmdToExec, $_.ToString())
                        throw $msg
                    }
                }
            }
            else {
                cmd.exe /D /C $cmdToExec

                if(-not $ignoreErrors -and ($LASTEXITCODE -ne 0)){
                    $msg = ('The command [{0}] exited with code [{1}]' -f $cmdToExec, $LASTEXITCODE)
                    throw $msg
                }
            }
        }
    }
}

function Execute-Command {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$exePath,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        [String]$arguments
        )
    process{
        $psi = New-Object -TypeName System.Diagnostics.ProcessStartInfo
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError=$true
        $psi.FileName = $exePath
        $psi.Arguments = $arguments

        $process = New-Object -TypeName System.Diagnostics.Process
        $process.StartInfo = $psi
        $process.EnableRaisingEvents=$true

        # Register the event handler for error
        $stdErrEvent = Register-ObjectEvent -InputObject $process  -EventName 'ErrorDataReceived' -Action {
            if (! [String]::IsNullOrEmpty($EventArgs.Data)) {
             $EventArgs.Data | Write-Error 
            }
        }

        # Starting process.
        $process.Start() | Out-Null
        $process.BeginErrorReadLine() | Out-Null
        $output = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit() | Out-Null
        $output | Write-Output
        
        # UnRegister the event handler for error
        Unregister-Event -SourceIdentifier $stdErrEvent.Name | Out-Null
    }
}


function Get-MSDeploy{
    [cmdletbinding()]
    param()
    process{
        $installPath = $env:msdeployinstallpath

        if(!$installPath){
            $keysToCheck = @('hklm:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy\3','hklm:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy\2','hklm:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy\1')

            foreach($keyToCheck in $keysToCheck){
                if(Test-Path $keyToCheck){
                    $installPath = (Get-itemproperty $keyToCheck -Name InstallPath -ErrorAction SilentlyContinue | select -ExpandProperty InstallPath -ErrorAction SilentlyContinue)
                }

                if($installPath){
                    break;
                }
            }
        }

        if(!$installPath){
            throw "Unable to find msdeploy.exe, please install it and try again"
        }

        [string]$msdInstallLoc = (join-path $installPath 'msdeploy.exe')

        "Found msdeploy.exe at [{0}]" -f $msdInstallLoc | Write-Verbose
        
        $msdInstallLoc
    }
}

function InternalNormalize-MSDeployUrl{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [string]$serviceUrl,

        [ValidateSet('WMSVC','RemoteAgent','InProc')]
        [string]$serviceMethod = 'WMSVC'
    )
    process{
        $tempUrl = $serviceUrl
        $resultUrl = $serviceUrl

        $httpsStr = 'https://'
        $httpStr = 'http://'
        $msdeployAxd = 'msdeploy.axd'

        if(-not [string]::IsNullOrWhiteSpace($serviceUrl)){
            if([string]::Compare($serviceMethod,'WMSVC',[StringComparison]::OrdinalIgnoreCase) -eq 0){
                # if no http or https then add one
                if(-not ($serviceUrl.StartsWith($httpStr,[StringComparison]::OrdinalIgnoreCase) -or 
                            $serviceUrl.StartsWith($httpsStr,[StringComparison]::OrdinalIgnoreCase)) ){

                    $serviceUrl = [string]::Concat($httpsStr,$serviceUrl.TrimStart())
                }
                [System.Uri]$serviceUri = New-Object -TypeName 'System.Uri' $serviceUrl
                [System.UriBuilder]$serviceUriBuilder = New-Object -TypeName 'System.UriBuilder' $serviceUrl

                # if it's https and the port was not passed in override it to 8172
                if( ([string]::Compare('https',$serviceUriBuilder.Scheme,[StringComparison]::OrdinalIgnoreCase) -eq 0) -and
                     -not $serviceUrl.Contains((':{0}' -f $serviceUriBuilder.Port)) ) {
                    $serviceUriBuilder.Port = 8172
                }

                # if no path then add one
                if([string]::Compare('/',$serviceUriBuilder.Path,[StringComparison]::OrdinalIgnoreCase) -eq 0){
                    $serviceUriBuilder.Path = $msdeployAxd
                }

                $resultUrl = $serviceUriBuilder.Uri.AbsoluteUri
            }
            elseif([string]::Compare($serviceMethod,'RemoteAgent',[StringComparison]::OrdinalIgnoreCase) -eq 0){
                [System.UriBuilder]$serviceUriBuilder = New-Object -TypeName 'System.UriBuilder' $serviceUrl
                # http://{computername}/MSDEPLOYAGENTSERVICE
                # remote agent must use http
                $serviceUriBuilder.Scheme = 'http'
                $serviceUriBuilder.Path = '/MSDEPLOYAGENTSERVICE'
                
                $resultUrl = $serviceUriBuilder.Uri.AbsoluteUri
            }
            else{
                # see if it's for localhost
                [System.Uri]$serviceUri = New-Object -TypeName 'System.Uri' $serviceUrl
                $resultUrl = $serviceUri.AbsoluteUri
            }
        }

        # return the result to the caller
        $resultUrl        
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

        'Registering MSDeploy package handler' | Write-Verbose
        Register-AspnetPublishHandler -name 'Package' -force -handler {
            [cmdletbinding()]
            param(
                [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
                $publishProperties,
                [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
                $packOutput
            )

            Publish-AspNetMSDeployPackage -publishProperties $publishProperties -packOutput $packOutput
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
