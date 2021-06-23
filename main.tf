terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

variable "Password" {
  type = string
}

variable "resource_group_name" {
  default = "Test"
}
variable "vnet_address_space"{
  default = "10.0.0.0/16"
}
variable "subnet_prefix" {
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}
provider "azurerm" {
  version = "=2.0.0"
  features {}
}
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "Australia East"
}
# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet" {
  name = "terraform-network"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  address_space = ["${var.vnet_address_space}"]
}
resource "azurerm_subnet" "subnet" {
  count = "${length(var.subnet_prefix)}"
  name = "appsubnet-${count.index}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix = "${element(var.subnet_prefix, count.index)}"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "test-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name = "Port80"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "80"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

    security_rule {
    name = "Port443"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "443"
    destination_port_range = "443"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}
 
resource "azurerm_subnet_network_security_group_association" "nsga" {
  count = "${length(var.subnet_prefix)}"
  subnet_id = azurerm_subnet.subnet.*.id[count.index]
  network_security_group_id = azurerm_network_security_group.nsg.id
}

 resource "azurerm_network_interface" "nic" {
   count = "${length(var.subnet_prefix)}"
   name                = "AZ-VM-00-NIC-${count.index}"
   location            = azurerm_resource_group.rg.location
   resource_group_name = azurerm_resource_group.rg.name
 ip_configuration {
     name                          = "internal"
     subnet_id                     = azurerm_subnet.subnet.*.id[count.index]
     private_ip_address_allocation = "Dynamic"
   }
 }

  resource "azurerm_windows_virtual_machine" "rg" {
   count = "${length(var.subnet_prefix)}" 
   name                = "AZ-VM-00-${count.index}"
   resource_group_name = azurerm_resource_group.rg.name
   location            = azurerm_resource_group.rg.location
   size                = "Standard_F2"
   admin_username      = admin_user
   admin_password      = var.Password
   network_interface_ids = [
     azurerm_network_interface.nic.*.id[count.index],
   ]
 os_disk {
     caching              = "ReadWrite"
     storage_account_type = "Standard_LRS"
   }
 source_image_reference {
     publisher = "MicrosoftWindowsServer"
     offer     = "WindowsServer"
     sku       = "2016-Datacenter"
     version   = "latest"
   }
 }

resource "azurerm_storage_account" "sa" {
  name                     = "storageaccountname"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}