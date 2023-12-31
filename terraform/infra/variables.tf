variable "enable_db_internet_access" {}
variable "cidr_subnets" {}
variable "web_instance_count" {}
variable "web_instance_type" {}
variable "db_instance_type" {}
variable "ubuntu_version" {}
variable "ssh_key" {}
variable "os_ami_owner" {}
variable "port_ssh" {}
variable "port_web" {}
variable "port_db" {}
variable "web_rules" {}

locals {
    build_id = basename(dirname(abspath("${path.root}")))
    web_rules = {
        ingress = [
            [var.port_ssh, "0.0.0.0/0", "SSH enabled"],
            [var.port_web, "0.0.0.0/0", "Apache2 (HTTP) enabled"]
        ]
        egress = [
            [0, "0.0.0.0/0", "Full outbound traffic enabled"]
        ]
    }
    db_rules = {
        ingress = [
            for instance in aws_instance.wp_web_instances: [
                var.port_db, "${instance.private_ip}/32", "MariaDB enabled for ${instance.tags.Name}"
            ]
        ]
        egress = []
    }
}