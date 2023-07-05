terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.6.2"
    }
  }
}

provider "aws" { region = var.region }

module "infra" {
  source = "./infra"
  cidr_public_subnet = var.cidr_public_subnet
  cidr_private_subnet = var.cidr_private_subnet
  web_instance_count = var.web_instance_count
  web_instance_type = var.web_instance_type
  db_instance_type = var.db_instance_type
  ubuntu_version = var.ubuntu_version
  ssh_key = var.ssh_key
  os_ami_owner = var.os_ami_owner
}