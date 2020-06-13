provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  version = "~>2.0"
  features {}
  subscription_id = var.arm_subscription_id
  client_id       = var.arm_principal
  client_secret   = var.arm_password
  tenant_id       = var.tenant_id

}

#RG#
resource "azurerm_resource_group" "Flashcards" {
  name     = "Flashcards"
  location = "westus"

  tags = {
    environment = "Terraform Demo"
  }
}

#Networking#

resource "azurerm_virtual_network" "FlashcardsNetwork" {
  name                = "FlashcardsNet"
  address_space       = ["10.0.0.0/16"]
  location            = "westus"
  resource_group_name = azurerm_resource_group.Flashcards.name
}

resource "azurerm_subnet" "FlashcardsSubnet" {
  name                 = "FlashcardsSubnet"
  resource_group_name  = azurerm_resource_group.Flashcards.name
  virtual_network_name = azurerm_virtual_network.FlashcardsNetwork.name
  address_prefixes     = ["10.0.2.0/29"]
}

resource "azurerm_public_ip" "FlashcardsPublicIp" {
  name                = "FlashcardsPublicIp"
  location            = "westus"
  resource_group_name = azurerm_resource_group.Flashcards.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Terraform Demo"
  }
}
resource "azurerm_network_security_group" "FlashcardsNSG" {
  name                = "FlashcardsNSG"
  location            = "westus"
  resource_group_name = azurerm_resource_group.Flashcards.name

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

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_interface" "FlashcardsNIC" {
  name                = "FlashcardsNIC"
  location            = "westus"
  resource_group_name = azurerm_resource_group.Flashcards.name

  ip_configuration {
    name                          = "FlashcardsNicConfiguration"
    subnet_id                     = azurerm_subnet.FlashcardsSubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.FlashcardsPublicIp.id
  }

  tags = {
    environment = "Terraform Demo"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "FlashcardsNICSGA" {
  network_interface_id      = azurerm_network_interface.FlashcardsNIC.id
  network_security_group_id = azurerm_network_security_group.FlashcardsNSG.id
}

resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.Flashcards.name
  }

  byte_length = 8
}

resource "azurerm_storage_account" "FlashcardsStorageAccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.Flashcards.name
  location                 = "westus"
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags = {
    environment = "Terraform Demo"
  }
}


################
# Create VM
################

resource "azurerm_linux_virtual_machine" "FlashcardsVM" {
  name                = "Flashcards"
  resource_group_name = azurerm_resource_group.Flashcards.name
  location            = azurerm_resource_group.Flashcards.location
  size                = "Standard_B1s"
  admin_username      = var.vm_username
  admin_password      = var.vm_password

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.FlashcardsNIC.id,
  ]
  provision_vm_agent = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "remote-exec" {
    connection {
      host = azurerm_linux_virtual_machine.FlashcardsVM.public_ip_address
      type = "ssh"
      user = azurerm_linux_virtual_machine.FlashcardsVM.admin_username
      password = azurerm_linux_virtual_machine.FlashcardsVM.admin_password
    }
    
    inline = [
    "sudo apt update",
    "sudo apt upgrade -y",
    "sudo apt install python3-pip gunicorn3 nginx -y",
    "git clone https://github.com/kprocyszyn/Learning-Terraform-Flashcards.git",
    "pip3 install -r /home/${var.vm_username}/Learning-Terraform-Flashcards/Flashcards/requirements.txt",
    "sudo gunicorn3 -D flashcards:app --chdir /home/${var.vm_username}/Learning-Terraform-Flashcards/Flashcards", #run gunicorn as daemon
    "sudo rm /etc/nginx/sites-available/default", #remove default website
    "sudo cp /home/${var.vm_username}/Learning-Terraform-Flashcards/Config/nginx/default /etc/nginx/sites-available/default", #copy config for Flashcards
    "sudo service nginx restart"
    ]
  }

}

##############
#output
##############

output "FlashcardsVM_public_ip" {
  value = azurerm_linux_virtual_machine.FlashcardsVM.public_ip_address
}
