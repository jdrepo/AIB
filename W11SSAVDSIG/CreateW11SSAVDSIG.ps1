function add-firewallRule($NSG, $localPublicIp, $port) {
  # Pick random number for setting priority. It will exclude current priorities.
  $InputRange = 100..200
  $Exclude = ($NSG | Get-AzNetworkSecurityRuleConfig | select Priority).priority
  $RandomRange = $InputRange | Where-Object { $Exclude -notcontains $_ }
  $priority = Get-Random -InputObject $RandomRange
  $nsgParameters = @{
      Name                     = "Allow-$port-Inbound-$localPublicIp"
      Description              = "Allow port $port from local ip address $localPublicIp"
      Access                   = 'Allow'
      Protocol                 = "Tcp" 
      Direction                = "Inbound" 
      Priority                 = $priority 
      SourceAddressPrefix      = $localPublicIp 
      SourcePortRange          = "*"
      DestinationAddressPrefix = "*" 
      DestinationPortRange     = $port
  }
  $NSG | Add-AzNetworkSecurityRuleConfig @NSGParameters  | Set-AzNetworkSecurityGroup 
}


# Destination image resource group name
$imageResourceGroup = 'rg-avd-000-dev'

# Azure region
$location = 'westeurope'

# My public ip
$localpublicip = (Invoke-WebRequest -uri "https://api.ipify.org/").Content 


# Your Azure Subscription ID
$subscriptionID = (Get-AzContext).Subscription.Id
Write-Output $subscriptionID

# Create resource group if not already exists
# New-AzResourceGroup -Name $imageResourceGroup -Location $location

# Create user-assigned identity and set role permissions
$imageRoleDefName = "Azure Image Builder Image Creator"
$identityName = "midu-weu-001-dev"

if ($null -eq (Get-AzUserAssignedIdentity -Name $identityName -ResourceGroupName $imageResourceGroup -ErrorAction SilentlyContinue)) {
  Write-Host "Create User-Assigned Managed identity $identityName"  
  New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName -Location $location
}

# Store the identity resource and principal IDs in variables
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId

# Create Custom Role definition
if ($null -eq (Get-AzRoleDefinition -Name $imageRoleDefName -ErrorAction SilentlyContinue)) {
    $myRoleImageCreationUrl = 'https://raw.githubusercontent.com/azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json'
    $myRoleImageCreationPath = "$env:TEMP\myRoleImageCreation.json"

    Invoke-WebRequest -Uri $myRoleImageCreationUrl -OutFile $myRoleImageCreationPath -UseBasicParsing

    $Content = Get-Content -Path $myRoleImageCreationPath -Raw
    $Content = $Content -replace '<subscriptionID>', $subscriptionID
    $Content = $Content -replace '<rgName>', $imageResourceGroup
    $Content = $Content -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName
    $Content | Out-File -FilePath $myRoleImageCreationPath -Force

    New-AzRoleDefinition -InputFile $myRoleImageCreationPath
}

#Check Role Assignment
if ($null -eq (Get-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup" -ErrorAction SilentlyContinue)) {
    # grant role definition to image builder service principal
    $RoleAssignParams = @{
        ObjectId = $identityNamePrincipalId
        RoleDefinitionName = $imageRoleDefName
        Scope = "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
    }
    New-AzRoleAssignment @RoleAssignParams
}

# Define Azure Compute Gallery
$GalleryName = 'aci_weu_001_dev'
$imageDefName = 'AIB-AVD-W11SS'

# Define Image Version
$date = get-date -format "yyyy-MM-ddHH"
$counter = "01"
$imageversion = $date.Replace("-", ".")+$counter

# Name of the image to be created
$imageTemplateName = $imagedefname + "_" + $imageversion

# Create Azure Compute Gallery if not already exists
if ($null -eq (Get-AzGallery -Name $GalleryName -ErrorAction SilentlyContinue)) {
    New-AzGallery -GalleryName $GalleryName -ResourceGroupName $imageResourceGroup -Location $location
}

$GalleryParams = @{
    GalleryName = $GalleryName
    ResourceGroupName = $imageResourceGroup
    Location = $location
    Name = $imageDefName
    OsState = 'generalized'
    OsType = 'Windows'
    Publisher = 'MicrosoftWindowsDesktop'
    Offer = 'WindowsDesktop'
    Sku = 'w11-21h2-avd-ss'
    HyperVGeneration = "V2"
  }

if ($null -eq (Get-AzGalleryImageDefinition -GalleryName $GalleryName -Name $imageDefName -ResourceGroupName $imageResourceGroup -ErrorAction SilentlyContinue)) {
New-AzGalleryImageDefinition @GalleryParams
}

# Distribution properties object name (runOutput).
# This gives you the properties of the managed image on completion.
$runOutputName="AIB-AVD-W11SS"


$templateFilePath = "CreateW11SSAVDSIGG2.json"

Invoke-WebRequest `
   -Uri "https://raw.githubusercontent.com/jdrepo/AIB/main/W11MSAVDSIG/CreateW11MSAVDSIGG2.json" `
   -OutFile $templateFilePath `
   -UseBasicParsing


(Get-Content -path $templateFilePath -Raw ) -replace '<subscriptionID>',$subscriptionID | Set-Content -Path $templateFilePath
(Get-Content -path $templateFilePath -Raw ) -replace '<rgName>',$imageResourceGroup | Set-Content -Path $templateFilePath
(Get-Content -path $templateFilePath -Raw ) -replace '<runOutputName>',$runOutputName | Set-Content -Path $templateFilePath
(Get-Content -path $templateFilePath -Raw ) -replace '<imageDefName>',$imageDefName | Set-Content -Path $templateFilePath
(Get-Content -path $templateFilePath -Raw ) -replace '<sharedImageGalName>',$GalleryName | Set-Content -Path $templateFilePath
(Get-Content -path $templateFilePath -Raw ) -replace '<region1>',$location | Set-Content -Path $templateFilePath
(Get-Content -path $templateFilePath -Raw ) -replace '<version>',$imageversion | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>',$identityNameResourceId) | Set-Content -Path $templateFilePath

# Remove existing image template, because update/upgrade is not supported
if ($null -ne (Get-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup -ErrorAction SilentlyContinue )) {
    Remove-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup
}

# Create the image version
New-AzResourceGroupDeployment `
   -ResourceGroupName $imageResourceGroup `
   -TemplateFile $templateFilePath `
   -imageTemplateName $imageTemplateName `
   -api-version "2021-10-01" `
   -svclocation $location `
   -imageversion $imageversion

# Build the image
<# Invoke-AzResourceAction `
   -ResourceName $imageTemplateName `
   -ResourceGroupName $imageResourceGroup `
   -ResourceType Microsoft.VirtualMachineImages/imageTemplates `
   -ApiVersion "2021-10-01" `
   -Action Run
#>

Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName -AsJob


# Get image build status
$getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -ImageTemplateName $imageTemplateName)

# this shows all the properties
$getStatus | Format-List -Property *

# these show the status of the build
$getStatus.LastRunStatusRunState 
$getStatus.LastRunStatusMessage
$getStatus.LastRunStatusRunSubState



while ($getStatus.LastRunStatusRunState -ne "Succeeded") {
  Write-Host "LastRunStatusRunState:  $($getStatus.LastRunStatusRunState) "
  Write-Host "LastRunStatusMessage: $($getStatus.LastRunStatusMessage)"
  Write-Host "LastRunStatusSubState: $($getStatus.LastRunStatusRunSubState)"
  $getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)
  Start-Sleep -Seconds 20
}

# Get Image Builder Output
$AIBRunOutput = (Get-AzImageBuilderRunOutput -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup)
$AIBRunOutput.ArtifactId

# Get latest image from ACG
$latestImageVersion = (Get-AzGalleryImageVersion -ResourceGroupName $imageResourceGroup -GalleryName $galleryName `
                        -GalleryImageDefinitionName $imagedefname)[-1] 

Get-AzGalleryImageVersion `
-ResourceGroupName $imageResourceGroup `
-GalleryName $GalleryName `
-GalleryImageDefinitionName $imageDefName

(Get-AzGalleryImageVersion -ResourceGroupName $imageResourceGroup -GalleryName $galleryName `
-GalleryImageDefinitionName $imagedefname) | sort-object -Property name -Descending   | fl name      

# Create VM from SIG image

$vmResourceGroup = "rg-trash-001"
$vmlocation = "westeurope"
$vmname = "aibtest"
$Cred = Get-Credential
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name mySubnet -AddressPrefix 192.168.1.0/24
$vnet = New-AzVirtualNetwork -ResourceGroupName $vmResourceGroup -Location $vmlocation `
  -Name MYvNET -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig
$pip = New-AzPublicIpAddress -ResourceGroupName $vmResourceGroup -Location $vmlocation -Name "mypublicdns$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name myNetworkSecurityGroupRuleRDP  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 3389 -Access Deny
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $vmResourceGroup -Location $vmlocation `
  -Name myNetworkSecurityGroup -SecurityRules $nsgRuleRDP
Add-firewallRule -NSG $nsg -localPublicIp $localPublicIp -port 3389
$nic = New-AzNetworkInterface -Name myNic -ResourceGroupName $vmResourceGroup -Location $vmlocation `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# Create a virtual machine configuration using $imageVersion.Id to specify the image
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize Standard_B2s | `
Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred | `
Set-AzVMSourceImage -Id $latestimageVersion.Id | `
Add-AzVMNetworkInterface -Id $nic.Id

# Create a virtual machine
New-AzVM -ResourceGroupName $vmResourceGroup -Location $vmlocation -VM $vmConfig


