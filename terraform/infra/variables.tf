variable "enable_db_internet_access" {}
variable "cidr_subnets" {}
variable "web_instance_count" {}
variable "web_instance_type" {}
variable "db_instance_type" {}
variable "ubuntu_version" {}
variable "ssh_key" {}
variable "os_ami_owner" {}
variable "port_web" {}
variable "port_db" {}
variable "web_rules" {}

locals {
    web_rules = {
        ingress = [
            [22, "0.0.0.0/0", "SSH enabled"],
            [var.port_web, "0.0.0.0/0", "Apache2 (HTTP) enabled"]
        ]
        egress = [
            [0, "0.0.0.0/0", "Full outbound traffic enabled"]
        ]
    }
    db_rules = {
        ingress = [
            [var.port_db, "${aws_instance.wp_db_instance.private_ip}/32", "MariaDB enabled"]
        ]
        egress = []
    }
}