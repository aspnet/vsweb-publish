[cmdletbinding(SupportsShouldProcess=$true)]
param($publishProperties, $packOutput, $nugetUrl)

# to learn more about this file visit http://go.microsoft.com/fwlink/?LinkId=524327
$publishModuleVersion = '1.0.1-beta1'
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

$defaultPublishSettings = New-Object psobject -Property @{
    LocalInstallDir = ("{0}Extensions\Microsoft\Web Tools\Publish\Scripts\{1}\" -f (Get-VisualStudio2015InstallPath),'1.0.1' )
}

function Enable-PackageDownloader{
    [cmdletbinding()]
    param(
        $toolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\package-downloader-$publishModuleVersion\",
        $pkgDownloaderDownloadUrl = 'http://go.microsoft.com/fwlink/?LinkId=524325') # package-downloader.psm1
    process{
        if(get-module package-downloader){
            remove-module package-downloader | Out-Null
        }

        if(!(get-module package-downloader)){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory -WhatIf:$false }

            $expectedPath = (Join-Path ($toolsDir) 'package-downloader.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $pkgDownloaderDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($pkgDownloaderDownloadUrl, $expectedPath)
            }
        
            if(!$expectedPath){throw ('Unable to download package-downloader.psm1')}

            'importing module [{0}]' -f $expectedPath | Write-Output
            Import-Module $expectedPath -DisableNameChecking -Force
        }
    }
}

function Enable-PublishModule{
    [cmdletbinding()]
    param()
    process{
        if(get-module publish-module){
            remove-module publish-module | Out-Null
        }

        if(!(get-module publish-module)){
            $localpublishmodulepath = Join-Path $defaultPublishSettings.LocalInstallDir 'publish-module.psm1'
            if(Test-Path $localpublishmodulepath){
                'importing module [publish-module="{0}"] from local install dir' -f $localpublishmodulepath | Write-Verbose
                Import-Module $localpublishmodulepath -DisableNameChecking -Force
                $true
            }
        }
    }
}

function Publish-DockerContainerApp{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,Position = 0)]
        $publishProperties,
        [Parameter(Mandatory = $true,Position = 1)]
        $packOutput
    )
    process {
    
        $dockerServerUrl = $publishProperties["DockerServerUrl"]
        $imageName = $publishProperties["DockerImageName"]
        $baseImageName = $publishProperties["DockerBaseImageName"]
        $hostPort = $publishProperties["DockerPublishHostPort"]
        $containerPort = $publishProperties["DockerPublishContainerPort"]
        $commandOptions = $publishProperties["DockerCommandOptions"]
        $appType = $publishProperties["DockerAppType"]
        $buildOnly = [System.Convert]::ToBoolean($publishProperties["DockerBuildOnly"])
        $removeConflictingContainers = [System.Convert]::ToBoolean($publishProperties["DockerRemoveConflictingContainers"])

        "Package output path: {0}" -f $packOutput | Write-Verbose
        "DockerHost: {0}" -f $dockerServerUrl | Write-Verbose
        "DockerImageName: {0}" -f $imageName | Write-Verbose
        "DockerBaseImageName: {0}" -f $baseImageName | Write-Verbose
        "DockerPublishHostPort: {0}" -f $hostPort | Write-Verbose
        "DockerPublishContainerPort: {0}" -f $containerPort | Write-Verbose
        "DockerCommandOptions: {0}" -f $commandOptions | Write-Verbose
        "DockerAppType: {0}" -f $appType | Write-Verbose
        "DockerBuildOnly: {0}" -f $buildOnly | Write-Verbose
        "DockerRemoveConflictingContainers: {0}" -f $removeConflictingContainers | Write-Verbose

        # set docker host information
        $command = '$env:DOCKER_HOST = "{0}"' -f $dockerServerUrl
        $command | Print-CommandString
        $command | Execute-CommandString -useInvokeExpression | Write-Verbose

        if($removeConflictingContainers){
            # remove all containers with the same port mapping to the host
            'Querying for conflicting containers which has the same port mapped...' | Write-Verbose
            $command = 'docker {0} ps -a | select-string -pattern ":{1}->" | foreach {{ Write-Output $_.ToString().split()[0] }}' -f $commandOptions,$hostPort
            $command | Print-CommandString
            $oldContainerIds = ($command | Execute-CommandString -useInvokeExpression)
            if ($oldContainerIds) {
                $oldContainerIds = $oldContainerIds -Join ' '
                'Cleaning up old containers {0}' -f $oldContainerIds | Write-Verbose
                $command = 'docker {0} rm -f {1}' -f $commandOptions,$oldContainerIds
                $command | Print-CommandString
                $command | Execute-CommandString | Write-Verbose
            }
        }

        'Building docker image: {0}' -f $imageName | Write-Verbose
        $command = 'docker {0} build -t {1} {2}' -f $commandOptions,$imageName,$packOutput
        $command | Print-CommandString
        $command | Execute-CommandString | Write-Verbose

        if(-not $buildOnly){
            'Starting docker container: {0}' -f $imageName | Write-Verbose
            $command = 'docker {0} run -t -d -p {1}:{2} {3}' -f $commandOptions,$hostPort,$containerPort,$imageName
            $command | Print-CommandString
            $containerId = ($command | Execute-CommandString)
            'New container ID: {0}' -f $containerId | Write-Verbose
            
            if($appType -eq "Web") {
                $hostName = ([System.Uri]$dockerServerUrl).Host
                if(-not $hostName) {
                    $hostName = ([System.Uri]"http://$dockerServerUrl").Host
                }
                $url = 'http://{0}:{1}' -f $hostName, $hostPort
                
                if(Test-WebPage -url $url -attempts $global:AspNetPublishSettings.DockerDefaultProperties.TestWebPageAttempts){
                    $command = 'Start-Process -FilePath "{0}"' -f $url
                    $command | Execute-CommandString -useInvokeExpression -ignoreErrors
                    'Application Url: {0}' -f $url | Write-Output
                }
                else {
                    'Web page "{0}" cannot be reached. If the Docker server is in Azure, please make sure the endpoint "{1}" is already opened from Azure portal.' -f $url,$hostPort | Write-Output
                }
            }
        }
        else {
            'Container was not started because DockerBuildOnly flag was set to True' | Write-Verbose
        }
        'Publish completed.' | Write-Output
    }
}

try{

    if (!(Enable-PublishModule)){
        Enable-PackageDownloader
        Enable-NuGetModule -name 'publish-module' -version $publishModuleVersion -nugetUrl $nugetUrl
    }

    'Calling Publish-AspNet' | Write-Verbose
    # call Publish-AspNet to perform the publish operation
    Publish-AspNet -publishProperties $publishProperties -packOutput $packOutput -Verbose
}
catch{
    "An error occured during publish.`n{0}" -f $_.Exception.Message | Write-Error
}