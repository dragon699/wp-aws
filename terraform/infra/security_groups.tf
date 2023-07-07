resource "aws_security_group" "wp_web_sg" {
    name = "wp_web_sg-${local.build_id}"
    description = "Wordpress servers security group"
    vpc_id = aws_vpc.wp_vpc.id

    dynamic "ingress" {
        iterator = rule
        for_each = local.web_rules["ingress"]

      content {
          protocol = "tcp"
          from_port = rule.value[0]
          to_port = rule.value[0]
          cidr_blocks = [rule.value[1]]
          description = rule.value[2]
      }
    }
    
    egress {
        protocol = "-1"
        from_port = local.web_rules["egress"][0][0]
        to_port = local.web_rules["egress"][0][0]
        cidr_blocks = [local.web_rules["egress"][0][1]]
        description = local.web_rules["egress"][0][2]
    }
}

resource "aws_security_group" "wp_db_sg" {
    name = "wp_db_sg-${local.build_id}"
    description = "Wordpress database server security group"
    vpc_id = aws_vpc.wp_vpc.id
}

# Attaching the rules for the DB group separately from
# the creation of the group itself, as there's a rule that
# references the private IP, visible after the vm creation
resource "aws_vpc_security_group_ingress_rule" "attach_rules_for_db" {
    count = length(local.db_rules["ingress"])
    security_group_id = aws_security_group.wp_db_sg.id
    depends_on = [aws_instance.wp_db_instance]

    ip_protocol = "tcp"
    from_port = local.db_rules["ingress"][count.index][0]
    to_port = local.db_rules["ingress"][count.index][0]
    cidr_ipv4 = local.db_rules["ingress"][count.index][1]
    description = local.db_rules["ingress"][count.index][2]
}