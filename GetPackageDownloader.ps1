<#
    You should add the snippet below to your PS files to ensure that PackageDownloader is available.
#>

function Enable-PackageDownloader{
    [cmdletbinding()]
    param($toolsDir = ("$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\tools\"),$nugetDownloadUrl = 'http://nuget.org/nuget.exe')
    process{
        if(!(get-module package-downloader)){            
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory | Out-Null }

            $modPath = (join-path $toolsDir 'package-downloader.0.0.17-beta\tools\package-downloader.psm1')
            if(!(Test-Path $modPath)){
                $nugetArgs = @('install','package-downloader','-prerelease','-version','0.0.17-beta','-OutputDirectory',(Resolve-Path $toolsDir).ToString())
                $nugetDestPath = Join-Path -Path $toolsDir -ChildPath nuget.exe
                if(!(Test-Path $nugetDestPath)){ (New-Object System.Net.WebClient).DownloadFile($nugetDownloadUrl, $nugetDestPath) | Out-Null }
                if(!(Test-Path $nugetDestPath)){ throw 'unable to download nuget' }
                &$nugetDestPath $nugetArgs
            }
            import-module $modPath -DisableNameChecking -force
        }
    }
}

Enable-PackageDownloader
