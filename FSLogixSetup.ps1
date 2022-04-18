<#Author       : Jens Diedrich ( Dean Cefola )
# Creation Date: 04-18-2022
# Usage        : Setup FSLogix without config
# based on https://raw.githubusercontent.com/DeanCefola/Azure-WVD/master/PowerShell/FSLogixSetup.ps1

#********************************************************************************
# Date                         Version      Changes
#------------------------------------------------------------------------
# 04/18/2022                     1.0        Intial Version
#
#
#*********************************************************************************
#
#>



######################
#    WVD Variables   #
######################
$LocalWVDpath            = "c:\temp\wvd\"
$FSLogixURI              = 'https://aka.ms/fslogix_download'
$FSInstaller             = 'FSLogixAppsSetup.zip'


####################################
#    Test/Create Temp Directory    #
####################################
if((Test-Path c:\temp) -eq $false) {
    Add-Content -LiteralPath C:\New-WVDSessionHost.log "Create C:\temp Directory"
    Write-Host `
        -ForegroundColor Cyan `
        -BackgroundColor Black `
        "creating temp directory"
    New-Item -Path c:\temp -ItemType Directory
}
else {
    Add-Content -LiteralPath C:\New-WVDSessionHost.log "C:\temp Already Exists"
    Write-Host `
        -ForegroundColor Yellow `
        -BackgroundColor Black `
        "temp directory already exists"
}
if((Test-Path $LocalWVDpath) -eq $false) {
    Add-Content -LiteralPath C:\New-WVDSessionHost.log "Create C:\temp\WVD Directory"
    Write-Host `
        -ForegroundColor Cyan `
        -BackgroundColor Black `
        "creating c:\temp\wvd directory"
    New-Item -Path $LocalWVDpath -ItemType Directory
}
else {
    Add-Content -LiteralPath C:\New-WVDSessionHost.log "C:\temp\WVD Already Exists"
    Write-Host `
        -ForegroundColor Yellow `
        -BackgroundColor Black `
        "c:\temp\wvd directory already exists"
}
New-Item -Path c:\ -Name New-WVDSessionHost.log -ItemType File
Add-Content `
-LiteralPath C:\New-WVDSessionHost.log `
"
ProfilePath       = $ProfilePath
RegistrationToken = $RegistrationToken
Optimize          = $Optimize
"


#################################
#    Download WVD Componants    #
#################################
Add-Content -LiteralPath C:\New-WVDSessionHost.log "Downloading FSLogix"
    Invoke-WebRequest -Uri $FSLogixURI -OutFile "$LocalWVDpath$FSInstaller"


##############################
#    Prep for WVD Install    #
##############################
Add-Content -LiteralPath C:\New-WVDSessionHost.log "Unzip FSLogix"
Expand-Archive `
    -LiteralPath "C:\temp\wvd\$FSInstaller" `
    -DestinationPath "$LocalWVDpath\FSLogix" `
    -Force `
    -Verbose
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
cd $LocalWVDpath 
Add-Content -LiteralPath C:\New-WVDSessionHost.log "UnZip FXLogix Complete"


#########################
#    FSLogix Install    #
#########################
Add-Content -LiteralPath C:\New-WVDSessionHost.log "Installing FSLogix"
$fslogix_deploy_status = Start-Process `
    -FilePath "$LocalWVDpath\FSLogix\x64\Release\FSLogixAppsSetup.exe" `
    -ArgumentList "/install /quiet" `
    -Wait `
    -Passthru





#############
#    END    #
#############
