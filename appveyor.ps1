$env:ExitOnPesterFail = $true
$env:IsDeveloperMachine=$true
$env:PesterEnableCodeCoverage = $true

if($env:APPVEYOR_REPO_BRANCH -ne "release"){
    .\build.ps1 -build
} 
else {
    .\build.ps1 -build -publishToNuget
}