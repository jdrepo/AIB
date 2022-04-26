# set regKey
write-host 'AIB Customization: Set required regKey'
New-Item -Path HKLM:\SOFTWARE\Microsoft -Name "Teams" 
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Teams -Name "IsWVDEnvironment" -Type "Dword" -Value "1"
write-host 'AIB Customization: Finished Set required regKey'
 
 
# install vc
write-host 'AIB Customization: Install the latest Microsoft Visual C++ Redistributable'
$appName = 'teams'
$drive = 'C:\'
New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
$LocalPath = $drive + '\' + $appName 
set-Location $LocalPath
$visCplusURL = 'https://aka.ms/vs/16/release/vc_redist.x64.exe'
$visCplusURLexe = 'vc_redist.x64.exe'
$outputPath = $LocalPath + '\' + $visCplusURLexe
Invoke-WebRequest -Uri $visCplusURL -OutFile $outputPath
write-host 'AIB Customization: Starting Install the latest Microsoft Visual C++ Redistributable'
Start-Process -FilePath $outputPath -Args "/install /quiet /norestart /log vcdist.log" -Wait
write-host 'AIB Customization: Finished Install the latest Microsoft Visual C++ Redistributable'
 
 
# install webSoc svc
write-host 'AIB Customization: Install the Teams WebSocket Service'
$webSocketsURL = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt'
$webSocketsInstallerMsi = 'webSocketSvc.msi'
$outputPath = $LocalPath + '\' + $webSocketsInstallerMsi
Invoke-WebRequest -Uri $webSocketsURL -OutFile $outputPath
Start-Process -FilePath msiexec.exe -Args "/I $outputPath /quiet /norestart /log webSocket.log" -Wait
write-host 'AIB Customization: Finished Install the Teams WebSocket Service'

# uninstall old Teams package
write-host 'AIB Customization: Uninstall MS Teams if installed'

$AppName = "Teams Machine-Wide Installer"
$Process = "Teams*"

ForEach ( $Architecture in "SOFTWARE", "SOFTWARE\Wow6432Node" ) { 
$UninstallKeys = "HKLM:\$Architecture\Microsoft\Windows\CurrentVersion\Uninstall"
if (Test-path $UninstallKeys) {
    Write-Output "Checking for $AppName installation in $UninstallKeys"
    $GUID = Get-ItemProperty -Path "$UninstallKeys\*" | 
    Where-Object -FilterScript { $_.DisplayName -like $AppName } |
    Select-Object PSChildName -ExpandProperty PSChildName

    If ( $GUID ) {
        Write-Output "Stopping $AppName Processes"
        Get-Process $Process | Stop-Process -Force
        $GUID | ForEach-Object {
            Write-Output "Uninstalling: $(( Get-ItemProperty "$UninstallKeys\$_" ).DisplayName) " 
            Start-Process -Wait -FilePath "MsiExec.exe" -ArgumentList "/X$_ /qn /norestart"
        }
    }
}
}
 
# install Teams
write-host 'AIB Customization: Install MS Teams'
$teamsURL = 'https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true'
$teamsMsi = 'teams.msi'
$outputPath = $LocalPath + '\' + $teamsMsi
Invoke-WebRequest -Uri $teamsURL -OutFile $outputPath
Start-Process -FilePath msiexec.exe -Args "/I $outputPath /quiet /norestart /log teams.log ALLUSER=1 ALLUSERS=1" -Wait
write-host 'AIB Customization: Finished Install MS Teams' 
 