# obtain available ubuntu images
data "aws_ami" "wp_ami" {
    most_recent = true

    name_regex = "^ubuntu/images/hvm-ssd/ubuntu-.*${var.ubuntu_version}-amd64-server-.*"
    owners = [var.os_ami_owner]

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

# generate new key (if required)
resource "tls_private_key" "new_ssh_key" {
  count = (var.ssh_key == "create") ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# put the key into an AWS key-pair
resource "aws_key_pair" "ssh_key" {
  key_name   = "wp-key-${local.build_id}" # extracts current build ID from the path name
  public_key = (var.ssh_key == "create") ? tls_private_key.new_ssh_key[0].public_key_openssh : var.ssh_key
}

# create VMs for the web servers
resource "aws_instance" "wp_web_instances" {
    count           = var.web_instance_count
    ami             = data.aws_ami.wp_ami.id
    instance_type   = var.web_instance_type
    key_name        = aws_key_pair.ssh_key.key_name
    associate_public_ip_address = true

    subnet_id       = aws_subnet.wp_subnets[count.index].id
    vpc_security_group_ids = [aws_security_group.wp_web_sg.id]

    tags = {
        Name = "WP-WEB-${count.index}-${local.build_id}"
        Description = "Wordpress (apache2 + php8) #${count.index}"
        SSH_port = var.port_ssh
    }
}

# create VM for the database
resource "aws_instance" "wp_db_instance" {
    ami             = data.aws_ami.wp_ami.id
    instance_type   = var.db_instance_type
    key_name        = aws_key_pair.ssh_key.key_name
    associate_public_ip_address = true

    subnet_id       = aws_subnet.wp_subnets[0].id
    vpc_security_group_ids = [aws_security_group.wp_db_sg.id]
    

    tags = {
        Name = "WP-DB-0-${local.build_id}"
        Description = "Wordpress (mariadb) #1"
    }
}