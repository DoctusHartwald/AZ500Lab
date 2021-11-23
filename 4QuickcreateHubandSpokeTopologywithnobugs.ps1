#Install the Az module if you haven't done so already.
#Install-Module Az
 
#Login to your Azure account.
#Login-AzAccount
 
# High Level parameters for Azure resources.
$azureLocation              = "westeurope"
$azureResourceGroup         = "RGhubandspoke"

#High level parameters for the virtual machine.
$vmAdminUsername = "student"
$vmAdminPassword = ConvertTo-SecureString "Azerty000000" -AsPlainText -Force
$azureVmSize                = "Standard_B1s"
#Define the VM marketplace image details.
$azureVmPublisherName = "MicrosoftWindowsServer"
$azureVmOffer = "WindowsServer"
$azureVmSkus = "2019-Datacenter"

# Create Resource GROUP *******
New-AzResourceGroup -Name $azureResourceGroup -Location $azureLocation 

# *******************************
# CREATE VNET INFRASTRUCTURE 
# *******************************
# create VnetHUB and subnet(s)
$azurevnetname = "VnetHub"
$vnet = @{
    Name = $azurevnetname
    ResourceGroupName = $azureResourceGroup
    Location = $azureLocation
    AddressPrefix = '10.0.0.0/16'    
}
$virtualNetwork = New-AzVirtualNetwork @vnet

$subnet = @{
    Name = 'subnethub0'
    VirtualNetwork = $virtualNetwork
    AddressPrefix = '10.0.0.0/24'
}
$subnetConfig = Add-AzVirtualNetworkSubnetConfig @subnet
$virtualNetwork | Set-AzVirtualNetwork

$subnet = @{
    Name = 'subnethub1'
    VirtualNetwork = $virtualNetwork
    AddressPrefix = '10.0.1.0/24'
}
$subnetConfig = Add-AzVirtualNetworkSubnetConfig @subnet
$virtualNetwork | Set-AzVirtualNetwork
# END create VnetHUB and subnet(s)

# create VnetSPOKE1 and subnet
$azurevnetname = "VnetSpoke1"
$vnet = @{
    Name = $azurevnetname
    ResourceGroupName = $azureResourceGroup
    Location = $azureLocation
    AddressPrefix = '10.1.0.0/16'    
}
$virtualNetwork = New-AzVirtualNetwork @vnet

$subnet = @{
    Name = 'subnetspoke1'
    VirtualNetwork = $virtualNetwork
    AddressPrefix = '10.1.0.0/24'
}
$subnetConfig = Add-AzVirtualNetworkSubnetConfig @subnet
$virtualNetwork | Set-AzVirtualNetwork
# END create VnetSPOKE1 and subnet

# create VnetSPOKE2 and subnet
$azurevnetname = "VnetSpoke2"
$vnet = @{
    Name = $azurevnetname
    ResourceGroupName = $azureResourceGroup
    Location = $azureLocation
    AddressPrefix = '10.2.0.0/16'    
}
$virtualNetwork = New-AzVirtualNetwork @vnet

$subnet = @{
    Name = 'subnetspoke2'
    VirtualNetwork = $virtualNetwork
    AddressPrefix = '10.2.0.0/24'
}
$subnetConfig = Add-AzVirtualNetworkSubnetConfig @subnet
$virtualNetwork | Set-AzVirtualNetwork
# END create VnetSPOKE2 and subnet

# *******************************
# CREATE VM INFRASTRUCTURE on HUB
# *******************************

# VMHUB0 on SUBNETHUB0
# *******************************

#Define local variables or this VM
$vmComputerName             = "VMhub0"
$azureVmName                = "VMhub0"
$azureVmOsDiskName          = "VMhub0_OS_DISK"
$azureNSGname               = "VMhub0_NSG"
$azureNicName               = "VMhub0-NIC"
$azurePublicIpName          = "VMhub0-IP"
 
#Define the existing VNet information.
$azureVnetName              = "Vnethub"
$azureVnetSubnetName        = "subnethub0"

#Get the subnet details for the specified virtual network + subnet combination.
$azureVnetSubnet = (Get-AzVirtualNetwork -Name $azureVnetName -ResourceGroupName $azureResourceGroup).Subnets | Where-Object {$_.Name -eq $azureVnetSubnetName}
 
#Create the public IP address.
$azurePublicIp = New-AzPublicIpAddress -Name $azurePublicIpName -ResourceGroupName $azureResourceGroup -Location $azureLocation -AllocationMethod Dynamic
 
#Create the NIC and associate the public IpAddress.
$azureNIC = New-AzNetworkInterface -Name $azureNicName -ResourceGroupName $azureResourceGroup -Location $azureLocation -SubnetId $azureVnetSubnet.Id -PublicIpAddressId $azurePublicIp.Id

# Optional Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig `
  -Name RDPOK `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 100 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3389 `
  -Access Allow

# Optional Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzNetworkSecurityRuleConfig `
  -Name HTTPOK `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 150 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 80 `
  -Access Allow

# Create a network security group
$nsg = New-AzNetworkSecurityGroup `
  -ResourceGroupName $azureResourceGroup `
  -Location $azurelocation `
  -Name $azureNSGname `
  -SecurityRules $nsgRuleRDP,$nsgRuleWeb

# Associate a network security group to VM Nic
# $nsg = Get-AzNetworkSecurityGroup -Name $azureNSGname -ResourceGroupName $azureResourceGroup
# $vmnic = Get-AzNetworkInterface -name "tamops-vm-nic"
$azurenic.NetworkSecurityGroup = $nsg
$azurenic | Set-AzNetworkInterface
 
#Store the credentials for the local admin account.
$vmCredential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $vmAdminPassword)
 
#Define the parameters for the new virtual machine.
$VirtualMachine = New-AzVMConfig -VMName $azureVmName -VMSize $azureVmSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $vmComputerName -Credential $vmCredential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $azureNIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $azureVmPublisherName -Offer $azureVmOffer -Skus $azureVmSkus -Version "latest"
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -StorageAccountType "Premium_LRS" -Caching ReadWrite -Name $azureVmOsDiskName -CreateOption FromImage
 
#Create the virtual machine.
New-AzVM -ResourceGroupName $azureResourceGroup -Location $azureLocation -VM $VirtualMachine -Verbose

# VMHUB1 on SUBNETHUB1
# *******************************
#Define local variables or this VM
$vmComputerName             = "VMhub1"
$azureVmName                = "VMhub1"
$azureVmOsDiskName          = "VMhub1_OS_DISK"
$azureNSGname               = "VMhub1_NSG"
$azureNicName               = "VMhub1-NIC"
$azurePublicIpName          = "VMhub1-IP"
 
#Define the existing VNet information.
$azureVnetName              = "Vnethub"
$azureVnetSubnetName        = "subnethub1"

#Get the subnet details for the specified virtual network + subnet combination.
$azureVnetSubnet = (Get-AzVirtualNetwork -Name $azureVnetName -ResourceGroupName $azureResourceGroup).Subnets | Where-Object {$_.Name -eq $azureVnetSubnetName}
 
#Create the public IP address.
$azurePublicIp = New-AzPublicIpAddress -Name $azurePublicIpName -ResourceGroupName $azureResourceGroup -Location $azureLocation -AllocationMethod Dynamic
 
#Create the NIC and associate the public IpAddress.
$azureNIC = New-AzNetworkInterface -Name $azureNicName -ResourceGroupName $azureResourceGroup -Location $azureLocation -SubnetId $azureVnetSubnet.Id -PublicIpAddressId $azurePublicIp.Id

# Optional Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig `
  -Name RDPOK `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 100 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3389 `
  -Access Allow

# Optional Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzNetworkSecurityRuleConfig `
  -Name HTTPOK `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 150 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 80 `
  -Access Allow

# Create a network security group
$nsg = New-AzNetworkSecurityGroup `
  -ResourceGroupName $azureResourceGroup `
  -Location $azurelocation `
  -Name $azureNSGname `
  -SecurityRules $nsgRuleRDP,$nsgRuleWeb

# Associate a network security group to VM Nic
# $nsg = Get-AzNetworkSecurityGroup -Name $azureNSGname -ResourceGroupName $azureResourceGroup
# $vmnic = Get-AzNetworkInterface -name "tamops-vm-nic"
$azurenic.NetworkSecurityGroup = $nsg
$azurenic | Set-AzNetworkInterface
 
#Store the credentials for the local admin account.
$vmCredential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $vmAdminPassword)
 
#Define the parameters for the new virtual machine.
$VirtualMachine = New-AzVMConfig -VMName $azureVmName -VMSize $azureVmSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $vmComputerName -Credential $vmCredential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $azureNIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $azureVmPublisherName -Offer $azureVmOffer -Skus $azureVmSkus -Version "latest"
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -StorageAccountType "Premium_LRS" -Caching ReadWrite -Name $azureVmOsDiskName -CreateOption FromImage
 
#Create the virtual machine.
New-AzVM -ResourceGroupName $azureResourceGroup -Location $azureLocation -VM $VirtualMachine -Verbose
# ************************************
# CREATE VM INFRASTRUCTURE on SPOKE1
# ************************************

#Define local variables or this VM
$vmComputerName             = "VMspoke1"
$azureVmName                = "VMspoke1"
$azureVmOsDiskName          = "VMspoke1_OS_DISK"
$azureNSGname               = "VMspoke1_NSG"
$azureNicName               = "VMspoke1-NIC"
$azurePublicIpName          = "VMspoke1-IP"
 
#Define the existing VNet information.
$azureVnetName              = "VnetSpoke1"
$azureVnetSubnetName        = "subnetspoke1"
 
#Define the VM marketplace image details.
$azureVmPublisherName = "MicrosoftWindowsServer"
$azureVmOffer = "WindowsServer"
$azureVmSkus = "2019-Datacenter"

#Get the subnet details for the specified virtual network + subnet combination.
$azureVnetSubnet = (Get-AzVirtualNetwork -Name $azureVnetName -ResourceGroupName $azureResourceGroup).Subnets | Where-Object {$_.Name -eq $azureVnetSubnetName}
 
#Create the public IP address.
$azurePublicIp = New-AzPublicIpAddress -Name $azurePublicIpName -ResourceGroupName $azureResourceGroup -Location $azureLocation -AllocationMethod Dynamic
 
#Create the NIC and associate the public IpAddress.
$azureNIC = New-AzNetworkInterface -Name $azureNicName -ResourceGroupName $azureResourceGroup -Location $azureLocation -SubnetId $azureVnetSubnet.Id -PublicIpAddressId $azurePublicIp.Id

# Optional Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig `
  -Name RDPOK `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 100 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3389 `
  -Access Allow

# Optional Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzNetworkSecurityRuleConfig `
  -Name HTTPOK `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 150 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 80 `
  -Access Allow

# Create a network security group
$nsg = New-AzNetworkSecurityGroup `
  -ResourceGroupName $azureResourceGroup `
  -Location $azurelocation `
  -Name $azureNSGname `
  -SecurityRules $nsgRuleRDP,$nsgRuleWeb

# Associate a network security group to VM Nic
# $nsg = Get-AzNetworkSecurityGroup -Name $azureNSGname -ResourceGroupName $azureResourceGroup
# $vmnic = Get-AzNetworkInterface -name "tamops-vm-nic"
$azurenic.NetworkSecurityGroup = $nsg
$azurenic | Set-AzNetworkInterface
 
#Store the credentials for the local admin account.
$vmCredential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $vmAdminPassword)
 
#Define the parameters for the new virtual machine.
$VirtualMachine = New-AzVMConfig -VMName $azureVmName -VMSize $azureVmSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $vmComputerName -Credential $vmCredential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $azureNIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $azureVmPublisherName -Offer $azureVmOffer -Skus $azureVmSkus -Version "latest"
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -StorageAccountType "Premium_LRS" -Caching ReadWrite -Name $azureVmOsDiskName -CreateOption FromImage
 
#Create the virtual machine.
New-AzVM -ResourceGroupName $azureResourceGroup -Location $azureLocation -VM $VirtualMachine -Verbose

# ************************************
# CREATE VM INFRASTRUCTURE on SPOKE2
# ************************************
#Define local variables or this VM
$vmComputerName             = "VMspoke2"
$azureVmName                = "VMspoke2"
$azureVmOsDiskName          = "VMspoke2_OS_DISK"
$azureNSGname               = "VMspoke2_NSG"
$azureNicName               = "VMspoke2-NIC"
$azurePublicIpName          = "VMspoke2-IP"
 
#Define the existing VNet information.
$azureVnetName              = "VnetSpoke2"
$azureVnetSubnetName        = "subnetspoke2"
 
#Define the VM marketplace image details.
$azureVmPublisherName = "MicrosoftWindowsServer"
$azureVmOffer = "WindowsServer"
$azureVmSkus = "2019-Datacenter"

#Get the subnet details for the specified virtual network + subnet combination.
$azureVnetSubnet = (Get-AzVirtualNetwork -Name $azureVnetName -ResourceGroupName $azureResourceGroup).Subnets | Where-Object {$_.Name -eq $azureVnetSubnetName}
 
#Create the public IP address.
$azurePublicIp = New-AzPublicIpAddress -Name $azurePublicIpName -ResourceGroupName $azureResourceGroup -Location $azureLocation -AllocationMethod Dynamic
 
#Create the NIC and associate the public IpAddress.
$azureNIC = New-AzNetworkInterface -Name $azureNicName -ResourceGroupName $azureResourceGroup -Location $azureLocation -SubnetId $azureVnetSubnet.Id -PublicIpAddressId $azurePublicIp.Id

# Optional Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig `
  -Name RDPOK `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 100 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3389 `
  -Access Allow

# Optional Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzNetworkSecurityRuleConfig `
  -Name HTTPOK `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 150 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 80 `
  -Access Allow

# Create a network security group
$nsg = New-AzNetworkSecurityGroup `
  -ResourceGroupName $azureResourceGroup `
  -Location $azurelocation `
  -Name $azureNSGname `
  -SecurityRules $nsgRuleRDP,$nsgRuleWeb

# Associate a network security group to VM Nic
# $nsg = Get-AzNetworkSecurityGroup -Name $azureNSGname -ResourceGroupName $azureResourceGroup
# $vmnic = Get-AzNetworkInterface -name "tamops-vm-nic"
$azurenic.NetworkSecurityGroup = $nsg
$azurenic | Set-AzNetworkInterface
 
#Store the credentials for the local admin account.
$vmCredential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $vmAdminPassword)
 
#Define the parameters for the new virtual machine.
$VirtualMachine = New-AzVMConfig -VMName $azureVmName -VMSize $azureVmSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $vmComputerName -Credential $vmCredential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $azureNIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $azureVmPublisherName -Offer $azureVmOffer -Skus $azureVmSkus -Version "latest"
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -StorageAccountType "Premium_LRS" -Caching ReadWrite -Name $azureVmOsDiskName -CreateOption FromImage
 
#Create the virtual machine.
New-AzVM -ResourceGroupName $azureResourceGroup -Location $azureLocation -VM $VirtualMachine -Verbose
