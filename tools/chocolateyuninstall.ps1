$unZipDir = "C:\RavenDB4"
$scriptDirectory = $unZipDir;
$rvn = "rvn.exe";
$serverDir = Join-Path $scriptDirectory "Server"
$name = 'RavenDB'
 
Push-Location $serverDir;

Try
{
    Invoke-Expression -Command ".\$rvn windows-service unregister --service-name $name";
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