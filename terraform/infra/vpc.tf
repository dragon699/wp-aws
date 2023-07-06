data "aws_availability_zones" "zones" { state = "available" }

resource "aws_vpc" "wp_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "wp_vpc"
    Description = "WordPress cluster VPC"
  }
}

resource "aws_subnet" "wp_subnets" {
  count = 2
  map_public_ip_on_launch = true

  vpc_id = aws_vpc.wp_vpc.id
  cidr_block = var.cidr_subnets[count.index]
  availability_zone = data.aws_availability_zones.zones.names[count.index]

  tags = {
    Name = "wp_public_subnet-${count.index}"
    Description = "Wordpress Subnet #${count.index}"
  }
}

resource "aws_internet_gateway" "wp_igw" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "wp_igw"
    Description = "Wordpress cluster Internet Gateway"
  }
}

resource "aws_route_table" "wp_public_rt" {
  vpc_id = aws_vpc.wp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wp_igw.id
  }

  tags = {
    Name = "wp_public_rt"
    Description = "Wordpress cluster Public Route Table - for enabling internet traffic for all ECs in the subnet"
  }
}

resource "aws_route_table_association" "wp_public_rt_route" {
  count = 2
  subnet_id = aws_subnet.wp_subnets[count.index].id
  route_table_id = aws_route_table.wp_public_rt.id
}