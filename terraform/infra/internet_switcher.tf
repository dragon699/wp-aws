# Resources in this file I use whenever I need to switch on/off the internet
# on the MariaDB instance

data "http" "ansible_host_ip" {
  count = (var.enable_db_internet_access) ? 1 : 0
  url = "https://api.ipify.org?format=text"
}

resource "aws_vpc_security_group_egress_rule" "enable_internet_for_db" {
    count = (var.enable_db_internet_access) ? 1 : 0
    security_group_id = aws_security_group.wp_db_sg.id

    ip_protocol = "-1"
    from_port = -1
    to_port = -1
    cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "enable_ssh_for_db" {
    count = (var.enable_db_internet_access) ? 1 : 0
    security_group_id = aws_security_group.wp_db_sg.id

    ip_protocol = "tcp"
    from_port = var.port_ssh
    to_port = var.port_ssh
    cidr_ipv4 = "${data.http.ansible_host_ip[0].response_body}/32"
}