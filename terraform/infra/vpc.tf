resource "aws_vpc" "wp_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "wp_vpc"
    Description = "WordPress cluster VPC"
  }
}

resource "aws_subnet" "wp_subnets" {
  count = 2
  vpc_id = aws_vpc.wp_vpc.id
  cidr_block = (count.index == 0) ? var.cidr_public_subnet : var.cidr_private_subnet
  map_public_ip_on_launch = (count.index == 0) ? true : false

  tags = {
    Name = "wp_${(count.index == 0) ? "public" : "private"}_subnet"
    Description = "Wordpress ${(count.index == 0) ? "Web Servers" : "Database"} Subnet"
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
    Description = "Wordpress cluster Public Route Table - for enabling internet traffic for all ECs in the public subnet"
  }
}

resource "aws_route_table_association" "wp_public_rt_route" {
  subnet_id = aws_subnet.wp_subnets[0].id
  route_table_id = aws_route_table.wp_public_rt.id
}