---
title: TP DevOps - Terraform
author: Mathys Goncalves
---

# TP4 DevOps - Terraform
<div style="text-align: right"> Mathys Goncalves - BDIA </div>
</br>

L'objectif de ce TP est d'orchestrer la création d'une VM dans Azure avec Terraform.
</br>

## Azure Provider
</br>

We first need to define in *providers.tf* the provider and our subscription_id : 

```js
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}

  subscription_id = "765266c6-9a23-4638-af32-dd1e32613047"
}
```

We also define variables in *var.tf* to avoid duplication : 
```js
variable "region"{
  default       = "france central"
  description   = "Location of the resource group."
}
```

## VM Creation
</br>

### Azure Data

We need to define data which will be used in the next step :

```js
data "azurerm_resource_group" "tp4" { 
   name   =   "devops-TP2" 
} 

data "azurerm_virtual_network" "tp4" {
  name = "example-network"
  resource_group_name = data.azurerm_resource_group.tp4.name
}

data "azurerm_subnet" "tp4" {
  name                 = "internal"
  virtual_network_name = data.azurerm_virtual_network.tp4.name
  resource_group_name  = data.azurerm_resource_group.tp4.name
}
```
</br>

### Terraform Steps

Create public IPs
```ps
resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "PublicIP-20180414"
  location            = data.azurerm_virtual_network.tp4.location
  resource_group_name = data.azurerm_resource_group.tp4.name
  allocation_method   = "Dynamic"
}
```
</br>

Create Network Security Group and rule
```ps
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "myNetworkSecurityGroup"
  location            = data.azurerm_virtual_network.tp4.location
  resource_group_name = data.azurerm_resource_group.tp4.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
```
</br>

Create network interface
```ps
resource "azurerm_network_interface" "myterraformnic" {
  name                = "NIC-20180414"
  location            = data.azurerm_virtual_network.tp4.location
  resource_group_name =  data.azurerm_resource_group.tp4.name

  ip_configuration {
    name                          = "NicConfiguration-20180414"
    subnet_id                     = data.azurerm_subnet.tp4.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }
}
```
</br>

Connect the security group to the network interface
```ps
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.myterraformnic.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}
```
</br>

Create (and display) an SSH key
```ps
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```
</br>

Create virtual machine named *devops-20180414*.
```ps
resource "azurerm_linux_virtual_machine" "myterraformvm" {
  name                  = "devops-20180414"
  location              = data.azurerm_virtual_network.tp4.location
  resource_group_name   =  data.azurerm_resource_group.tp4.name
  network_interface_ids = [azurerm_network_interface.myterraformnic.id]
  size                  = "Standard_D2s_v3"

  os_disk {
    name                 = "OsDisk-20180414"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  computer_name                   = "devops-20180414"
  admin_username                  = "devops"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "devops"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }
}
```
</br>

### Ouput
</br>

We need to define output to get our public IP adress and private key needed to connect to the VM.
In a *output.tf* file :

```ps
output "public_ip_address" {
  value = azurerm_linux_virtual_machine.myterraformvm.public_ip_address
}

output "tls_private_key" {
  value     = tls_private_key.example_ssh.private_key_pem
  sensitive = true
}
```

## Run 


We need to login to Azure cli and then we can apply our script :
```ps
az login

terraform init # if any change -upgrade
terraform plan # Check the steps
terraform apply # Apply the steps 
```

```ps
[Output] 
    ...
    Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```
</br>

Your VM has been created and you can try it.
You need to run your output to get public IP and generate private key (in file name id_rsa) :

```ps
terraform output public_ip_address
```
```ps
[Output]
    "20.111.12.44"
```
</br>

```ps
terraform output -raw tls_private_key > id_rsa
```
</br>

Then you can try to get info from your VM : 

```ps
ssh -i id_rsa devops@20.111.12.44 cat /etc/os-release
```
```ps
[Output]
    The authenticity of host '20.111.12.44 (20.111.12.44)' can't be established.
    ED25519 key fingerprint is SHA256:P57YaIEcuGwDcfhBez/6YDTTitfYKAuOn76MsVLbHXU.
    This key is not known by any other names
    Are you sure you want to continue connecting (yes/no/[fingerprint])? yes

    Warning: Permanently added '20.111.12.44' (ED25519) to the list of known hosts.
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    Permissions 0644 for 'id_rsa' are too open.
    It is required that your private key files are NOT accessible by others.
    This private key will be ignored.
    Load key "id_rsa": bad permissions
    devops@20.111.12.44: Permission denied (publickey).
```

Here something gone wrong and it's due too right. Here everyone can have access too your private key store in your *id_rsa* file.
You will need to change right access : 
```
sudo chmod 600 id_rsa   
```
</br>

Let's try again to call the VM : 
```ps
ssh -i id_rsa devops@20.111.12.44 cat /etc/os-release
```
```ps
[Output]
    NAME="Ubuntu"
    VERSION="16.04.7 LTS (Xenial Xerus)"
    ID=ubuntu
    ...
    UBUNTU_CODENAME=xenial
```

Then destroy the VM when finished : 
```ps
terraform destroy
```
```
Destroy complete! Resources: 7 destroyed.
```
