write-host 'AIB Customization: Install Language Pack'
$drive = 'C:'
$folder = 'lp'
$azcopyloc = 'c:\temp'
$LpPath = $drive + '\' + $folder
$LpArchive = "w11-ml.zip"
$Lpack = $LpArchive.split(".")[0]
New-Item -Path ($drive+"\") -Name $folder -ItemType Directory -ErrorAction SilentlyContinue
Set-Location $LpPath

write-host 'AIB Customization: Start Download Language Pack'
$env:AZCOPY_CRED_TYPE = "Anonymous";
$env:AZCOPY_BUFFER_GB = "1";
Set-Location $azcopyloc
c:\temp\azcopy.exe copy "https://saweuconfigjd.blob.core.windows.net/aib/w11-ml.zip?sv=2020-10-02&st=2022-05-01T11%3A41%3A53Z&se=2032-05-02T11%3A41%3A00Z&sr=b&sp=r&sig=Qz1kQlG2Vq6cqPF1erJhPNqcb%2B5RqZfaNABb%2BFJyA3g%3D" $LpPath --overwrite=prompt --check-md5 FailIfDifferent --from-to=BlobLocal --recursive --log-level=INFO
$env:AZCOPY_CRED_TYPE = "";
write-host 'AIB Customization: Stop Download Language Pack'
write-host 'AIB Customization: Start Expand Language Pack'
Expand-Archive "$LpPath\$LpArchive" $LpPath
write-host 'AIB Customization: Stop Expand Language Pack'
########################################################
## Add Languages to running Windows Image for Capture##
########################################################
##Disable Language Pack Cleanup##
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\MUI\" -TaskName "LPRemove"
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "Uninstallation"
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Control Panel\International" /v "BlockCleanupOfUnusedPreinstalledLangPacks" /t REG_DWORD /d 1 /f

write-host 'AIB Customization: Prepare Language Pack Import'


##Set Language Pack Content Stores##
Set-Location $LpPath
$LIPContent = "$LpPath\$Lpack\LanguagesAndOptionalFeatures"

##Set Path of CSV File##
$CSVFile = "Windows-10-1809-FOD-to-LP-Mapping-Table.csv"
$filePath = "$LpPath\$Lpack\$CSVFile"

##Import Necesarry CSV File##
$FODList = Import-Csv -Path $filePath -Delimiter ";"

##Set Language (Target)##
$targetLanguage = "de-de"

$sourceLanguage = (($FODList | Where-Object {$_.'Target Lang' -eq $targetLanguage}) | Where-Object {$_.'Source Lang' -ne $targetLanguage} | Select-Object -Property 'Source Lang' -Unique).'Source Lang'
if(!($sourceLanguage)){
    $sourceLanguage = $targetLanguage
}

$langGroup = (($FODList | Where-Object {$_.'Target Lang' -eq $targetLanguage}) | Where-Object {$_.'Lang Group:' -ne ""} | Select-Object -Property 'Lang Group:' -Unique).'Lang Group:'

##List of additional features to be installed##
$additionalFODList = @(
    "$LIPContent\Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~~.cab", 
    "$LIPContent\Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~amd64~$sourceLanguage~.cab",
    "$LIPContent\Microsoft-Windows-SnippingTool-FoD-Package~31bf3856ad364e35~amd64~$sourceLanguage~.cab",
    "$LIPContent\Microsoft-Windows-Lip-Language_x64_$sourceLanguage.cab" ##only if applicable##
)

$additionalCapabilityList = @(
 "Language.Basic~~~$sourceLanguage~0.0.1.0",
 "Language.Handwriting~~~$sourceLanguage~0.0.1.0",
 "Language.OCR~~~$sourceLanguage~0.0.1.0",
 "Language.Speech~~~$sourceLanguage~0.0.1.0",
 "Language.TextToSpeech~~~$sourceLanguage~0.0.1.0"
 )

write-host 'AIB Customization: Perform Language Pack Import'


##Install all FODs or fonts from the CSV file###
if ( Test-Path -Path $LIPContent\Microsoft-Windows-Client-Language-Pack_x64_$sourceLanguage.cab ) {
    Dism /Online /Add-Package /PackagePath:$LIPContent\Microsoft-Windows-Client-Language-Pack_x64_$sourceLanguage.cab
}

if ( Test-Path -Path $LIPContent\Microsoft-Windows-Lip-Language-Pack_x64_$sourceLanguage.cab ) {
    Dism /Online /Add-Package /PackagePath:$LIPContent\Microsoft-Windows-Lip-Language-Pack_x64_$sourceLanguage.cab
}

foreach($capability in $additionalCapabilityList){
    Dism /Online /Add-Capability /CapabilityName:$capability /Source:$LIPContent
}

foreach($feature in $additionalFODList){
    if ( Test-Path -Path $feature ) {
        Dism /Online /Add-Package /PackagePath:$feature
    }
}

if($langGroup){
    Dism /Online /Add-Capability /CapabilityName:Language.Fonts.$langGroup~~~und-$langGroup~0.0.1.0 
}

##Add installed language to language list##
$LanguageList = Get-WinUserLanguageList
$LanguageList.Add("$targetlanguage")
Set-WinUserLanguageList $LanguageList -force

write-host 'AIB Customization: Get Language list'
Get-WinUserLanguageList

write-host 'AIB Customization: Delete Language files'
Set-Location $env:TEMP
Get-Item $LpPath  | Remove-Item -Recurse
