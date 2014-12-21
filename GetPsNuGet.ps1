<#
    You should add the snippet below to your PS files to ensure that PsNuGet is available.
#>

function Enable-PsNuGet{
    [cmdletbinding()]
    param($toolsDir = ("$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\tools\"),$nugetDownloadUrl = 'http://nuget.org/nuget.exe')
    process{
        if(!(get-module 'getnuget')){            
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory | Out-Null }

            $modPath = (join-path $toolsDir 'getnuget.0.0.15-beta\tools\getnuget.psm1')
            if(!(Test-Path $modPath)){
                $nugetArgs = @('install','getnuget','-prerelease','-version','0.0.15-beta','-OutputDirectory',(Resolve-Path $toolsDir).ToString())
                $nugetDestPath = Join-Path -Path $toolsDir -ChildPath nuget.exe
                if(!(Test-Path $nugetDestPath)){ (New-Object System.Net.WebClient).DownloadFile($nugetDownloadUrl, $nugetDestPath) | Out-Null }
                if(!(Test-Path $nugetDestPath)){ throw 'unable to download nuget' }
                &$nugetDestPath $nugetArgs
            }
            import-module $modPath -DisableNameChecking -force
        }
    }
}

Enable-PsNuGet
