terraform {
  required_version = ">=0.13"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">=2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg-exTerraformIaaS" {
  name     = "exTerraformIaaS"
  location = "brazilsouth"
}

resource "azurerm_virtual_network" "vn-exTerraformIaaS" {
  name                = "virtualNetwork"
  location            = azurerm_resource_group.rg-exTerraformIaaS.location
  resource_group_name = azurerm_resource_group.rg-exTerraformIaaS.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["8.8.8.8", "8.8.4.4"]

  tags = {
    aula = "2"
    exercicio = "TerraformIaaS"
  }
}

resource "azurerm_subnet" "sn-exTerraformIaaS" {
  name                 = "subNet"
  resource_group_name  = azurerm_resource_group.rg-exTerraformIaaS.name
  virtual_network_name = azurerm_virtual_network.vn-exTerraformIaaS.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ip-exTerraformIaaS" {
  name                    = "publicip"
  location                = azurerm_resource_group.rg-exTerraformIaaS.location
  resource_group_name     = azurerm_resource_group.rg-exTerraformIaaS.name
  allocation_method       = "Static"
}

resource "azurerm_network_security_group" "sg-exTerraformIaaS" {
  name                = "securityGroup"
  location            = azurerm_resource_group.rg-exTerraformIaaS.location
  resource_group_name = azurerm_resource_group.rg-exTerraformIaaS.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

    security_rule {
    name                       = "HTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "ni-exTerraformIaaS" {
  name                = "networkInterface"
  location            = azurerm_resource_group.rg-exTerraformIaaS.location
  resource_group_name = azurerm_resource_group.rg-exTerraformIaaS.name

  ip_configuration {
    name                          = "interface"
    subnet_id                     = azurerm_subnet.sn-exTerraformIaaS.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-exTerraformIaaS.id 
  }
}

resource "azurerm_network_interface_security_group_association" "ga-exTerraformIaaS" {
  network_interface_id      = azurerm_network_interface.ni-exTerraformIaaS.id   
  network_security_group_id = azurerm_network_security_group.sg-exTerraformIaaS.id

}

resource "azurerm_storage_account" "sa-exTerraformIaaS" {
  name                     = "exterraformiaas"
  resource_group_name      = azurerm_resource_group.rg-exTerraformIaaS.name
  location                 = azurerm_resource_group.rg-exTerraformIaaS.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_linux_virtual_machine" "vm-exTerraformIaaS" {
  name                = "vmLinux"
  resource_group_name = azurerm_resource_group.rg-exTerraformIaaS.name
  location            = azurerm_resource_group.rg-exTerraformIaaS.location
  #az vm list-skus --location brazilsouth --zone --size standard --output table
  size                = "Standard_E2bs_v5"
  admin_username      = "adminuser"
  admin_password      = "Password1234!"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.ni-exTerraformIaaS.id,
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    name = "osDisk"
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.sa-exTerraformIaaS.primary_blob_endpoint
  }
}

data "azurerm_public_ip" "ip-exTerraformIaaS-data"{
  name = azurerm_public_ip.ip-exTerraformIaaS.name
  resource_group_name = azurerm_resource_group.rg-exTerraformIaaS.name
}

resource "null_resource" "install-webserver" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-exTerraformIaaS-data.ip_address
    user = "adminuser"
    password = "Password1234!"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm-exTerraformIaaS
  ]
}
