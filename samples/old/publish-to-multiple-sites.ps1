[cmdletbinding()]
param(
    $srcDir = 'C:\Data\personal\mycode\aspnet_vnext_samples\web',
    $packOutDir = "c:\temp\publishtemp\packout-pub-multiple"
)

function BuildAndPack{
    [cmdletbinding()]
    param(
        $rootSrcdir,
        $packOutdir,
        [switch]
        $nosource
    )
    begin{ Push-Location }
    end{ Pop-Location }
    process{
        $srcDir = (get-item $rootSrcdir).FullName
        Set-Location $srcDir
'*********************************************
building and packing [{0}]
*********************************************' -f $srcDir | Write-Output
'***** restoring nuget packages ****' | Write-Output
        kpm restore

'**** building project ****' | Write-Output
        kpm build

'**** packing to [{0}] ****' -f $outdir | Write-Output
        if(!(Test-Path $packOutdir)){New-Item $packOutdir -ItemType Directory}
        $outdir = (get-item $packOutdir).FullName
        $kpmPackArgs = @('pack', '-o', "$outdir")
        if($nosource){
            $kpmPackArgs+='--no-source'
        }
        'calling kpm pack with the args [kpm {0}]' -f ($kpmPackArgs -join (' ')) | Write-Output
        kpm $kpmPackArgs
    }
}

#################################################
# Begin script
#################################################

if(!(Test-Path $srcDir)){
    throw ('srcDir [{0}] not found' -f $srcDir)
}

if(Test-Path $packOutDir){Remove-Item $packOutDir -Recurse -Force}
New-Item $packOutDir -ItemType Directory

$outDirWithSoure = (new-item (join-path $packOutDir 'withsource') -ItemType Directory).FullName
BuildAndPack -rootSrcdir $srcDir -packOutdir $outDirWithSoure

$outDirNoSoure = (new-item (join-path $packOutDir 'nosource') -ItemType Directory).FullName
BuildAndPack -rootSrcdir $srcDir -packOutdir $outDirNoSoure -nosource

start "$packOutDir"
<#




Push-Location
Set-Location $srcDir
Pop-Location

if(Test-Path $pubTempDir){ Remove-Item $pubTempDir -Recurse -Force }
if(Test-Path $packOutDir){ Remove-Item $packOutDir -Recurse -Force }

New-Item $pubTempDir -ItemType Directory
New-Item $packOutDir -ItemType Directory

$packOutDir = (Get-Item $packOutDir).FullName

Push-Location

Set-Location $pubTempDir
git clone git@github.com:ligershark/aspnet_vnext_samples.git

Pop-Location


BuildAndPack -rootSrcdir "$pubTempDir\aspnet_vnext_samples" -name 'console' -packOutdir $packOutDir
BuildAndPack -rootSrcdir "$pubTempDir\aspnet_vnext_samples" -name 'web' -packOutdir $packOutDir
BuildAndPack -rootSrcdir "$pubTempDir\aspnet_vnext_samples" -name 'mvc' -packOutdir $packOutDir
'Pack complete to root [{0}]' -f $pubTempDir | Write-Output

start "$pubTempDir"
#>