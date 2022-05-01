########################################################
## Add Languages to running Windows Image for Capture##
########################################################
##Disable Language Pack Cleanup##
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\MUI\" -TaskName "LPRemove"
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "Uninstallation"
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Control Panel\International" /v "BlockCleanupOfUnusedPreinstalledLangPacks" /t REG_DWORD /d 1 /f


write-host 'AIB Customization: Install Language Pack'
$drive = 'C:'
$folder = 'lp'
$LpPath = $drive + '\' + $folder
New-Item -Path ($drive+"\") -Name $folder -ItemType Directory -ErrorAction SilentlyContinue
Set-Location $LpPath

write-host 'AIB Customization: Start - Download Language Pack ISO'
$env:AZCOPY_CRED_TYPE = "Anonymous";
$env:AZCOPY_BUFFER_GB = "1";
Set-Location $azcopyloc
c:\temp\azcopy.exe copy "https://saweuconfigjd.blob.core.windows.net/aib/20348.1.210507-1500.fe_release_amd64fre_SERVER_LOF_PACKAGES_OEM.iso?sv=2020-10-02&st=2022-05-01T11%3A44%3A41Z&se=2032-05-02T11%3A44%3A00Z&sr=b&sp=r&sig=DugYYr8PeoZM7xnvvi6r97YdMJUfdWmAzvmVSwIXr30%3D" $LpPath --overwrite=prompt --check-md5 FailIfDifferent --from-to=BlobLocal --recursive --log-level=INFO
$env:AZCOPY_CRED_TYPE = "";
write-host 'AIB Customization: Complete - Download Language Pack ISO'
write-host 'AIB Customization: Mount Download Language Pack ISO'
$LPIso = Mount-DiskImage -ImagePath "$LpPath\20348.1.210507-1500.fe_release_amd64fre_SERVER_LOF_PACKAGES_OEM.iso"
$LPDriveLetter = ($LPIso | Get-Volume).DriveLetter
$files = Get-ChildItem -Path "$($LPDriveLetter):\LanguagesAndOptionalFeatures"  -Filter "*de-de*"
##German##
write-host 'AIB Customization: Start - Add Language Pack'

foreach ($file in $files )
 {
   Add-WindowsPackage -Online -PackagePath $file.fullname
 }
write-host 'AIB Customization: Complete - Add Language Pack'
write-host 'AIB Customization: Remove Language Pack ISO'
Dismount-DiskImage -InputObject $LPIso
Set-Location $env:TEMP
Get-Item $LpPath  | Remove-Item -Recurse
