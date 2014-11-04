[cmdletbinding()]
param(
    $pubTempDir = 'c:\temp\publishtemp\e2e01',
    $packOutDir = (Join-Path $pubTempDir 'packout')
)

if(Test-Path $pubTempDir){ Remove-Item $pubTempDir -Recurse -Force }
if(Test-Path $packOutDir){ Remove-Item $packOutDir -Recurse -Force }

New-Item $pubTempDir -ItemType Directory
New-Item $packOutDir -ItemType Directory

$packOutDir = (Get-Item $packOutDir).FullName

Push-Location

Set-Location $pubTempDir
git clone git@github.com:ligershark/aspnet_vnext_samples.git

Pop-Location
function BuildAndPack{
    [cmdletbinding()]
    param(
        $rootSrcdir,
        $name,
        $packOutdir
    )
    begin{ Push-Location }
    end{ Pop-Location }
    process{
        $srcDir = (get-item (join-path $rootSrcdir $name)).FullName
        Set-Location $srcDir
'*********************************************
building and packing [{0}]
*********************************************' -f $srcDir | Write-Output
'***** restoring nuget packages ****' | Write-Output
        kpm restore

'**** building project ****' | Write-Output
        kpm build

'**** packing to [{0}] ****' -f $outdir | Write-Output
        $outdir = (new-item (join-path $packOutDir $name) -ItemType Directory).FullName
        kpm @('pack', '-o', "$outdir")
        Set-Location $outdir
    }
}

BuildAndPack -rootSrcdir "$pubTempDir\aspnet_vnext_samples" -name 'console' -packOutdir $packOutDir
BuildAndPack -rootSrcdir "$pubTempDir\aspnet_vnext_samples" -name 'web' -packOutdir $packOutDir
BuildAndPack -rootSrcdir "$pubTempDir\aspnet_vnext_samples" -name 'mvc' -packOutdir $packOutDir
'starting'|Write-Host -ForegroundColor Green
start "$pubTempDir"
