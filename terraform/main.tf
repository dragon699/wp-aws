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
  enable_db_internet_access = var.enable_db_internet_access
  cidr_subnets = var.cidr_subnets
  web_instance_count = var.web_instance_count
  web_instance_type = var.web_instance_type
  db_instance_type = var.db_instance_type
  ubuntu_version = var.ubuntu_version
  ssh_key = var.ssh_key
  os_ami_owner = var.os_ami_owner
  port_ssh = var.port_ssh
  port_web = var.port_web
  port_db = var.port_db
  web_rules = {}
}