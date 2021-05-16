terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.39.0"
    }
  }

  required_version = ">= 0.15.0"
}

provider "aws" {
  profile = "default"
  region  = var.aws_region
}

resource "aws_vpc" "quest_vpc" {
  cidr_block            = var.vpc_cidr
  enable_dns_hostnames  = true

  tags = {
    Name = "quest-vpc"
  }
}

resource "aws_subnet" "quest_public_sn_us_east_1e" {
  vpc_id     = aws_vpc.quest_vpc.id
  cidr_block = var.subnets_cidr[0]
  availability_zone = var.azs[0]

  tags = {
    Name = "quest-public-sn-us-east-1e"
  }
}

resource "aws_subnet" "quest_public_sn_us_east_1f" {
  vpc_id     = aws_vpc.quest_vpc.id
  cidr_block = var.subnets_cidr[1]
  availability_zone = var.azs[1]

  tags = {
    Name = "quest-public-sn-us-east-1f"
  }
}

resource "aws_internet_gateway" "quest_igw" {
  vpc_id = aws_vpc.quest_vpc.id

  tags = {
    Name = "quest-igw"
  }
}

resource "aws_route_table" "quest_vpc_rt_public" {
    vpc_id = aws_vpc.quest_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.quest_igw.id
    }

    tags = {
        Name = "quest-vpc-rt"
    }
}

resource "aws_route_table_association" "quest_rta_us_east_1e_public" {
    subnet_id = aws_subnet.quest_public_sn_us_east_1e.id
    route_table_id = aws_route_table.quest_vpc_rt_public.id
}

resource "aws_route_table_association" "quest_rta_us_east_1f_public" {
    subnet_id = aws_subnet.quest_public_sn_us_east_1f.id
    route_table_id = aws_route_table.quest_vpc_rt_public.id
}

resource "aws_security_group" "quest_sg" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      =  aws_vpc.quest_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

data "template_file" "quest_user_data" {
  template = <<EOF
#!/bin/bash
sudo yum update

sudo amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user

sudo chkconfig docker on

sudo yum install -y git

sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

mkdir /home/ec2-user/rearc/
cd /home/ec2-user/rearc/

git clone https://github.com/rearc/quest.git
git clone https://github.com/jesterjaimi/rearc-quest-proxy.git

cp rearc-quest-proxy/Dockerfile .
cp rearc-quest-proxy/docker-compose.yml .
cp -R rearc-quest-proxy/nginx nginx

sudo rm -fr rearc-quest-proxy

sudo chown -R ec2-user:ec2-user nginx
sudo chmod 400 ./nginx/certs/rearc.quest.crt
sudo chmod 400 ./nginx/certs/rearc.quest.key

cd ./nginx/
docker-compose up -d
EOF
}

resource "aws_launch_template" "quest_lt" {
  name_prefix   = "rearc-quest"
  image_id      = var.server_ami
  instance_type = "t2.micro"
  key_name = "rearc-quest"
  #vpc_security_group_ids = [aws_security_group.quest_sg.id]

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.quest_sg.id]
  }

  user_data = "${base64encode(data.template_file.quest_user_data.rendered)}"

  lifecycle {
    ignore_changes = [
      image_id,
    ]
  }
}

resource "aws_placement_group" "quest_pg" {
  name     = "quest-pg"
  strategy = "cluster"
}

resource "aws_autoscaling_group" "quest_asg" {
  name = "quest-asg"
  vpc_zone_identifier = [aws_subnet.quest_public_sn_us_east_1e.id, aws_subnet.quest_public_sn_us_east_1f.id]
  desired_capacity   = 2
  max_size           = 4
  min_size           = 1

  target_group_arns  = [ aws_lb_target_group.quest_tg.arn ]

  launch_template {
    id      = aws_launch_template.quest_lt.id
    version = "$Latest"
  }
}

resource "aws_lb_target_group" "quest_tg" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "quest-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.quest_vpc.id
}

resource "aws_lb" "quest_alb" {
  name     = "quest-alb"
  internal = false

  security_groups = [aws_security_group.quest_sg.id]

  subnets = [ aws_subnet.quest_public_sn_us_east_1e.id,  aws_subnet.quest_public_sn_us_east_1f.id]

  tags = {
    Name = "quest-alb"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

resource "aws_lb_listener" "quest_alb_listner" {
  load_balancer_arn = aws_lb.quest_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quest_tg.arn
  }
}

variable "aws_region" {
	default = "us-east-1"
}

variable "vpc_cidr" {
	default = "10.20.0.0/16"
}

variable "subnets_cidr" {
	type = list(string)
	default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "azs" {
	type = list(string)
	default = ["us-east-1e", "us-east-1f"]
}

variable "server_ami" {
  default = "ami-0d5eff06f840b45e9"
}

variable "instance_type" {
  default = "t2.micro"
}
