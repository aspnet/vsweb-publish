
# Ideas for improvements

 - Can we add an MSBuild property to pass ```-Verbose``` and ```-Debug```, that would enable 
   flowing messages from ```Write-Verbose``` and ```Write-Debg```. The idea is to let users set that in the .pubxml file.

 - In this script there is a call to ```Get-MSDeploy```. It will look at an env var
named MSDeployPath. I was thinking that VS can set this env var so that we
ensure the correct version of MSDeploy is picked up. Env var is preferred to passing this via ```$publishProperties``` because it applies across projects and is specific to the client.

 - How can we pass in the UserAgent string? We should have a different value
for script execution versus from VS. We should pass this in ```$PublishProperties``` and have a default that is set in the script.

 - There is a string casing issue when accessing dictionary objects when executing with VS. ```$publishProperties['publishUrl'] != $publishProperties['PublishUrl']``` for some reason.

 - Pass that path to the project in ```$PublishProperties```

- My thoughts are that we can add a new MSBuild property in .pubxml ```EnableCallKpmPackOnPublish```
 which is set to true by default in our .targets file. If the user adds that to .pubmxl
it will not call kpm pack.

  1. VS/MSBuild call KPM pack and then call .ps1. The idea is that the user will take
   the output and then publish to the web server
  2. User want's to completely customize publish and VS/MSBuild calling kpm pack is
   not needed. Instead they just need the path to the source folder.
