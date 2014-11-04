


$pubTempDir = 'c:\temp\publishtemp\e2e01'
$packOutDir = (Join-Path $pubTempDir 'packout')

if(Test-Path $pubTempDir){ Remove-Item $pubTempDir -Recurse -Force }
if(Test-Path $packOutDir){ Remove-Item $packOutDir -Recurse -Force }

New-Item $pubTempDir -ItemType Directory
New-Item $packOutDir -ItemType Directory

$packOutDir = (Get-Item $packOutDir).FullName

Push-Location

Set-Location $pubTempDir
git clone git@github.com:ligershark/aspnet_vnext_samples.git

Set-Location aspnet_vnext_samples\mvc

'*********************************************
restoring nuget packages
*********************************************' | Write-Output
kpm restore
'*********************************************
building project
*********************************************' | Write-Output
kpm build
$outdir = (join-path $packOutDir 'mvc')
new-item $outdir -ItemType Directory
$outdir = (get-item $outdir).FullName

'*********************************************
packing to [{0}]
*********************************************' -f $outdir | Write-Output

kpm @('pack', '-o', "$outdir")
Set-Location $outdir
#&((get-item(join-path $outdir 'kestrel.cmd')).FullName)

Pop-Location

