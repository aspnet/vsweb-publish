$env:ExitOnPesterFail = $true
$env:IsDeveloperMachine=$true
$env:PesterEnableCodeCoverage = $true
# $env:e2ePkgTestUseCustomMSDeploy=$true

if($env:APPVEYOR_REPO_BRANCH -eq 'release'){
    .\build.ps1 -build -publishToNuget
}
elseif($env:APPVEYOR_REPO_BRANCH -eq 'publish-staging'){
    .\build.ps1 -build -publishToNuget -nugetUrl https://staging.nuget.org -nugetApiKey $env:NuGetApiKeyStaging
}
else{
    .\build.ps1 -build
}