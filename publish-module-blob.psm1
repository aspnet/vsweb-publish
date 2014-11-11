[cmdletbinding(SupportsShouldProcess=$true)]
param()

function Publish-FolderToBlobStorage{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateScript({Test-Path $_ -PathType Container})] 
        $folder,
        [Parameter(Mandatory=$true,Position=1)]
        $storageAcctName,
        [Parameter(Mandatory=$true,Position=2)]
        $storageAcctKey,
        [Parameter(Mandatory=$true,Position=3)]
        $containerName
    )
    begin{
        'Publishing folder to blob storage. [folder={0},storageAcctName={1},storageContainer={2}]' -f $folder,$storageAcctName,$containerName | Write-Output
        Push-Location
        Set-Location $folder
        $destContext = New-AzureStorageContext -StorageAccountName $storageAcctName -StorageAccountKey $storageAcctKey
    }
    end{ Pop-Location }
    process{
        $allFiles = (Get-ChildItem $folder -Recurse -File).FullName

        foreach($file in $allFiles){
            $relPath = (Resolve-Path $file -Relative).TrimStart('.\')
            "relPath: [$relPath]" | Write-Output

            Set-AzureStorageBlobContent -Blob $relPath -File $file -Container $containerName -Context $destContext
        }
    }
}

'Registering blob storage handler' | Write-Verbose
Register-AspnetPublishHandler -name 'BlobStorage' -handler {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $PublishProperties,
        [Parameter(Mandatory = $true,Position=1,ValueFromPipelineByPropertyName=$true)]
        $OutputPath
    )
    
    '[op={0},san={1},con={2}' -f $OutputPath,$PublishProperties['StorageAcctName'],$PublishProperties['StorageContainer'] | Write-Output

    Publish-FolderToBlobStorage -folder $OutputPath -storageAcctName $PublishProperties['StorageAcctName'] -storageAcctKey $PublishProperties['StorageAcctKey'] -containerName $PublishProperties['StorageContainer']
}