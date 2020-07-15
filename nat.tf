provider "aws" {
  region     = "ap-south-1"
  profile    = "Anish"
}


resource "aws_vpc" "task" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "task_vpc"
  }
}


resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.task.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-subnet-1a"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.task.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name =  "Private-subnet-1b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.task.id

  tags = {
    Name = "task-igw"
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.task.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }



  tags = {
    Name = "task_routeTable"
  }
}

resource "aws_route_table_association" "route_asso" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route.id
}

resource "aws_eip" "task_ip" {
  vpc      = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "task_nat" {
  allocation_id = aws_eip.task_ip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "task NAT"
  }
}

resource "aws_route_table" "nat_route" {
  vpc_id = aws_vpc.task.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.task_nat.id
  }



  tags = {
    Name = "nat_task_routeTable"
  }
}

resource "aws_route_table_association" "nat_route_asso" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.nat_route.id
}

resource "aws_security_group" "allow_mysql" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.task.id

  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_mysql"
  }
}

resource "aws_instance" "Mysql" {
  ami           = "ami-0d09a307682d309f9"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.allow_mysql.id ]
  subnet_id = aws_subnet.private.id
  user_data = <<-EOF
        #!/bin/bash
        
        sudo docker run -dit -p 8080:3306 --name mysql -e MYSQL_ROOT_PASSWORD=redhat -e MYSQL_DATABASE=task-db -e MYSQL_USER=anish -e MYSQL_PASSWORD=redhat mysql:5.6
  EOF

  tags = {
    Name = "Mysql"
  }
}

resource "aws_security_group" "allow_wp" {
  name        = "allow_wp"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.task.id

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_wp"
  }
}

resource "aws_instance" "wp" {
  ami           = "ami-0d09a307682d309f9"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.allow_wp.id ]
  subnet_id = aws_subnet.public.id
  key_name      = "AnishKey"
  user_data = <<-EOF
        #!/bin/bash
        
        sudo docker run -dit -p 8000:80 --name wp wordpress:4.8-apache
  EOF

  tags = {
    Name = "Wordpress"
  }
}

output "WP_public_IP" {
  value = aws_instance.wp.public_ip
}

output "Mysql_private_IP" {
  value = aws_instance.Mysql.private_ip
}
