terraform {
  required_providers {
    azurerm = {
      version = "= 4.29.0"
      source  = "hashicorp/azurerm"
    }
    random = {
      version = "= 3.7.2"
      source  = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "instance_count" {
  default = "1"
}

variable "name" {
  default = "openqa-vm"
}

variable "type" {
  default = "Standard_B2s"
}

variable "region" {
  default = "westeurope"
}

variable "image_id" {
  default = ""
}

variable "image_uri" {
  default = ""
}

variable "publisher" {
  default = "SUSE"
}

variable "offer" {
  default = ""
}

variable "sku" {
  default = "gen2"
}

variable "root-disk-size" {
  default = 30
}

variable "extra-disk-size" {
  default = "100"
}

variable "extra-disk-type" {
  default = "Premium_LRS"
}

variable "create-extra-disk" {
  default = false
}

variable "cloud_init" {
  default = ""
}

variable "storage-account" {
  # Note: Don't delete the default value!!!
  # Not all of our `terraform destroy` calls pass this variable and neither is it necessary.
  # However removing the default value might cause `terraform destroy` to fail in corner cases,
  # resulting effectively in leaking resources due to failed cleanups.
  default = "eisleqaopenqa"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vm_create_timeout" {
  default = "20m"
}

variable "subnet_id" {
  default = ""
}

variable "ssh_public_key" {
  default = "/root/.ssh/id_rsa.pub"
}

resource "random_id" "service" {
  count = var.instance_count
  keepers = {
    name = var.name
  }
  byte_length = 8
}


resource "azurerm_resource_group" "openqa-group" {
  name     = "${var.name}-${element(random_id.service[*].hex, 0)}"
  location = var.region

  tags = merge({
    openqa_created_by   = var.name
    openqa_created_date = timestamp()
    openqa_created_id   = element(random_id.service[*].hex, 0)
  }, var.tags)
}

resource "azurerm_public_ip" "openqa-publicip" {
  name                = "${var.name}-${element(random_id.service[*].hex, count.index)}-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.openqa-group.name
  allocation_method   = "Static"
  count               = var.instance_count
}

resource "azurerm_network_interface" "openqa-nic" {
  name                = "${var.name}-${element(random_id.service[*].hex, count.index)}-nic"
  location            = var.region
  resource_group_name = azurerm_resource_group.openqa-group.name
  count               = var.instance_count

  ip_configuration {
    name                          = "${element(random_id.service[*].hex, count.index)}-nic-config"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.openqa-publicip[*].id, count.index)
  }
}

resource "azurerm_image" "image" {
  name                = "${azurerm_resource_group.openqa-group.name}-disk1"
  location            = var.region
  resource_group_name = azurerm_resource_group.openqa-group.name
  hyper_v_generation  = var.sku == "gen1" ? "V1" : "V2"
  count               = var.image_id != "" ? 1 : 0

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = "https://${var.storage-account}.blob.core.windows.net/sle-images/${var.image_id}"
    size_gb  = var.root-disk-size 
    storage_type = "Standard_LRS"
  }
}

resource "azurerm_linux_virtual_machine" "openqa-vm" {
  name                            = "${var.name}-${element(random_id.service[*].hex, count.index)}"
  resource_group_name             = azurerm_resource_group.openqa-group.name
  location                        = var.region
  size                            = var.type
  computer_name                   = "${var.name}-${element(random_id.service[*].hex, count.index)}"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  count = var.instance_count

  network_interface_ids = [azurerm_network_interface.openqa-nic[count.index].id]

  tags = merge({
    openqa_created_by   = var.name
    openqa_created_date = timestamp()
    openqa_created_id   = element(random_id.service[*].hex, count.index)
  }, var.tags)

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key)
  }

  os_disk {
    name                 = "${var.name}-${element(random_id.service[*].hex, count.index)}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    # SLE images are 30G by default. Uncomment this line in case we need to increase the disk size
    # note: value can not be decreased because 30 GB is minimum allowed by Azure
    disk_size_gb         = var.root-disk-size
  }

  source_image_id = var.image_uri != "" ? var.image_uri : (var.image_id != "" ? azurerm_image.image[0].id : null)
  dynamic "source_image_reference" {
    for_each = range(var.image_id == "" && var.image_uri == "" ? 1 : 0)
    content {
      publisher = var.image_id != "" ? "" : var.publisher
      offer     = var.image_id != "" ? "" : var.offer
      sku       = var.image_id != "" ? "" : var.sku
      version   = var.image_id != "" ? "" : "latest"
    }
  }

  boot_diagnostics {
    /* Passing a null value will utilize a Managed Storage Account to store Boot Diagnostics */
    storage_account_uri = null
  }

  timeouts {
    create = var.vm_create_timeout
  }

  custom_data = var.cloud_init != "" ? filebase64(var.cloud_init) : null
}

resource "azurerm_virtual_machine_data_disk_attachment" "default" {
  count              = var.create-extra-disk ? var.instance_count : 0
  managed_disk_id    = element(azurerm_managed_disk.ssd_disk[*].id, count.index)
  virtual_machine_id = element(azurerm_linux_virtual_machine.openqa-vm[*].id, count.index)
  lun                = "1"
  caching            = "ReadWrite"
}

resource "azurerm_managed_disk" "ssd_disk" {
  count                = var.create-extra-disk ? var.instance_count : 0
  name                 = "ssd-disk-${element(random_id.service[*].hex, count.index)}"
  location             = azurerm_resource_group.openqa-group.location
  resource_group_name  = azurerm_resource_group.openqa-group.name
  storage_account_type = var.extra-disk-type
  create_option        = "Empty"
  disk_size_gb         = var.extra-disk-size
}


output "vm_name" {
  value = azurerm_linux_virtual_machine.openqa-vm[*].id
}

data "azurerm_public_ip" "openqa-publicip" {
  name                = azurerm_public_ip.openqa-publicip[count.index].name
  resource_group_name = azurerm_linux_virtual_machine.openqa-vm[0].resource_group_name
  count               = var.instance_count
}

output "public_ip" {
  value = data.azurerm_public_ip.openqa-publicip[*].ip_address
}

output "instance_id" {
  value = azurerm_linux_virtual_machine.openqa-vm[*].id
}

output "resource_group_name" {
  value = azurerm_resource_group.openqa-group[*].name
}

