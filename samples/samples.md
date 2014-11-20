# Publish Samples

These samples rely on the following.

 - set ```$env:PublishPwd``` env var
 - Publish using VS and set the ```$OutputPath``` variable before calling the samples. Note this should ***not*** have ```wwwroot```.

### Standard MSDeploy publish

```
.\Properties\PublishProfiles\sayedkdemo2.ps1 -OutputPath $OutputPath -PublishProperties @{
     'WebPublishMethod'='MSDeploy'
     'MSDeployServiceURL'='sayedkdemo2.scm.azurewebsites.net:443';
'DeployIisAppPath'='sayedkdemo2';'Username'='$sayedkdemo2';'Password'="$env:PublishPwd"} -Verbose
```

### Standard file system publish

```
.\Properties\PublishProfiles\sayedkdemo2.ps1 -OutputPath $OutputPath -PublishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'='C:\temp\publish\new'
	} -Verbose
```

## Skipping files

### MSDeploy publish skipping two files

```
.\Properties\PublishProfiles\sayedkdemo2.ps1 -OutputPath $OutputPath -PublishProperties @{
     'WebPublishMethod'='MSDeploy'
     'MSDeployServiceURL'='sayedkdemo2.scm.azurewebsites.net:443';`
'DeployIisAppPath'='sayedkdemo2';'Username'='$sayedkdemo2';'Password'="$env:PublishPwd"
 	'ExcludeFiles'=@(
		@{'Filepath'='wwwroot\\test.txt'},
		@{'Filepath'='wwwroot\\_references.js'}
)} -Verbose
```

### File system publish skipping two files

```
.\Properties\PublishProfiles\sayedkdemo2.ps1 -OutputPath $OutputPath -PublishProperties @{
	'WebPublishMethod'='FileSystem'
	'publishUrl'='C:\temp\publish\new'
 	'ExcludeFiles'=@(
       @{'Filepath'='.*.cmd'},
		@{'Filepath'='wwwroot\test.txt'}
)} -Verbose
```


