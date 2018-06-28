
$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://hibernatingrhinos.com/downloads/RavenDB%20for%20Windows%20x86/40045' # download url, HTTPS preferred
$url64      = 'https://hibernatingrhinos.com/downloads/RavenDB%20for%20Windows%20x64/40045' # 64bit URL here (HTTPS preferred) or remove - if installer contains both (very rare), use $url
$pp = Get-PackageParameters
$unZipDir = "C:\RavenDB4"
if (!$pp['port']) { $pp['port'] = 8080 }
$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $unZipDir
  fileType      = 'EXE_MSI_OR_MSU' #only one of these: exe, msi, msu
  url           = $url
  url64bit      = $url64
  #file         = $fileLocation

  softwareName  = 'RavenDB4' #part or all of the Display Name as you see it in Programs and Features. It should be enough to be unique

  checksum      = '4569BE35E2B40A94F8004A7882A225CE61C566CDB83027D55D9CBC16A34D95D2'
  checksumType  = 'sha256' 
  checksum64    = '8C0E6525B6BB6518056676EAA5539E204DC46CF6BCCE19023E906152B7BF99F6'
  checksumType64= 'sha256' 
}


Install-ChocolateyZipPackage @packageArgs 

function CheckPortIsClosed($port) {
    $result = Test-NetConnection -Port $port -ComputerName 127.0.0.1 -InformationLevel Quiet 3> $null
    return $result -eq $false
}

function SetAclOnServerDirectory($dir) {
    $acl = Get-Acl $dir
    $permissions = "LocalService", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow"
    $rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $permissions
    $acl.SetAccessRuleProtection($False, $False)
    $acl.AddAccessRule($rule)
    Set-Acl -Path $dir -AclObject $acl
}

$scriptDirectory = $unZipDir;
$settingsTemplateJson = "settings.default.json";
$settingsJson = "settings.json";
$rvn = "rvn.exe";
$serverDir = Join-Path $scriptDirectory "Server"

SetAclOnServerDirectory $(Join-Path -Path $scriptDirectory -ChildPath "Server")

$settingsJsonPath = Join-Path $serverDir $settingsJson
$settingsTemplateJsonPath = Join-Path $serverDir $settingsTemplateJson;

$name = 'RavenDB'
 
$isAlreadyConfigured = Test-Path $settingsJsonPath

if ($isAlreadyConfigured) {
    write-host "Server was run before - attempt to use existing configuration."
    $serverUrl = $(Get-Content $settingsJsonPath -raw | ConvertFrom-Json).ServerUrl
} else {
    write-host "Server run for the first time."
	write-host "Installing on port $($pp['port'])"
	$port = $pp['port']

    if ($port -lt 0 -Or $port -gt 65535) {
        throw "Error. Port must be in the range 0-65535."
    }

    if ((CheckPortIsClosed $port) -eq $false) {
        throw "Port $port is not available.";
    }

    $json = Get-Content $settingsTemplateJsonPath -raw | ConvertFrom-Json
    $serverUrl = $json.ServerUrl = "http://127.0.0.1:$port"
    $json | ConvertTo-Json  | Set-Content $settingsTemplateJsonPath
}

Push-Location $serverDir;

Try
{
    Invoke-Expression -Command ".\$rvn windows-service register --service-name $name";
    Start-Service -Name $name
}
catch
{
    write-error $_.Exception
	throw $_.Exception
}
finally
{
    Pop-Location;
}

Write-Host "Service started, server listening on $serverUrl."
Write-Host "You can now finish setting up the RavenDB service in the browser."

Start-Sleep -Seconds 3
Start-Process $serverUrl 