terraform {
  required_providers {
    aws = {
      version = "= 5.14.0"
      source  = "hashicorp/aws"
    }
    random = {
      version = "= 3.1.0"
      source  = "hashicorp/random"
    }
  }
}

variable "region" {
  default = "eu-central-1"
}

provider "aws" {
  region = var.region
}

variable "instance_count" {
  default = "1"
}

variable "name" {
  default = "openqa-vm"
}

variable "type" {
  default = "t2.large"
}

variable "image_id" {
  default = ""
}

variable "extra-disk-size" {
  default = "1000"
}

variable "extra-disk-type" {
  default = "gp2"
}

variable "create-extra-disk" {
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vm_create_timeout" {
  default = "20m"
}

variable "enable_confidential_vm" {
  default = "disabled"
}

variable "vpc_security_group_ids" {
  default = ""
}

variable "availability_zone" {
  default = ""
}

variable "subnet_id" {
  default = ""
}

variable "ipv6_address_count" {
  default = 0
}

variable "ipv6_address" {
  default = ""
}

resource "random_id" "service" {
  count = var.instance_count
  keepers = {
    name = var.name
  }
  byte_length = 8
}

resource "aws_key_pair" "openqa-keypair" {
  key_name   = "openqa-${element(random_id.service.*.hex, 0)}"
  public_key = file("/root/.ssh/id_rsa.pub")
}

resource "aws_subnet" "ipv6" {
  count                  = var.instance_count

  availability_zone      = var.availability_zone
  vpc_id                  = "vpc-0d3affe22a06649a7" 
  ipv6_cidr_block                 = "2a05:d018:1c5f:4b66::/64"
  ipv6_native = true
  assign_ipv6_address_on_creation = true
  enable_resource_name_dns_aaaa_record_on_launch = true

  tags = merge({
    openqa_created_by   = var.name
    openqa_created_date = timestamp()
  }, var.tags)
}

resource "aws_route_table" "example" {
  count                  = var.instance_count
  vpc_id                  = "vpc-0d3affe22a06649a7" 

  route {
    ipv6_cidr_block = element(aws_subnet.ipv6.*.ipv6_cidr_block, count.index)
    network_interface_id = element(aws_network_interface.test.*.id, count.index)
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = "igw-025c387f2dde31516"
  }
}

resource "aws_route_table_association" "route-table-association" {
  count                  = var.instance_count

  subnet_id      = element(aws_subnet.ipv6.*.id, count.index)
  route_table_id = element(aws_route_table.example.*.id, count.index)
}

resource "aws_network_interface" "test" {
  count                  = var.instance_count

  subnet_id              = var.subnet_id
  ipv6_addresses         = (var.ipv6_address_count == "1") ? ["${var.ipv6_address}1"] : []
  security_groups = [var.vpc_security_group_ids]
  source_dest_check = false
}

resource "aws_instance" "openqa" {
  count                  = var.instance_count
  ami                    = var.image_id
  instance_type          = var.type
  key_name               = aws_key_pair.openqa-keypair.key_name
  availability_zone      = var.availability_zone

  network_interface {
    network_interface_id = element(aws_network_interface.test.*.id, count.index)
    device_index         = 0
  }

  tags = merge({
    openqa_created_by   = var.name
    openqa_created_date = timestamp()
    openqa_created_id   = element(random_id.service.*.hex, count.index)
  }, var.tags)

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 20
  }

  timeouts {
    create = var.vm_create_timeout
  }

  dynamic "cpu_options" {
    for_each = var.enable_confidential_vm == "disabled" ? [] : [1]
    content {
      amd_sev_snp = var.enable_confidential_vm
    }
  }
}

resource "aws_volume_attachment" "ebs_att" {
  count       = var.create-extra-disk ? var.instance_count : 0
  device_name = "/dev/sdb"
  volume_id   = element(aws_ebs_volume.ssd_disk.*.id, count.index)
  instance_id = element(aws_instance.openqa.*.id, count.index)
}

resource "aws_ebs_volume" "ssd_disk" {
  count             = var.create-extra-disk ? var.instance_count : 0
  availability_zone = element(aws_instance.openqa.*.availability_zone, count.index)
  size              = var.extra-disk-size
  type              = var.extra-disk-type
  tags = merge({
    openqa_created_by   = var.name
    openqa_created_date = timestamp()
    openqa_created_id   = element(random_id.service.*.hex, count.index)
  }, var.tags)
}

output "public_ip" {
  value = aws_instance.openqa.*.public_ip
}
output "public_ipv6" {
  value = aws_instance.openqa.*.ipv6_addresses
}

output "vm_name" {
  value = aws_instance.openqa.*.id
}
