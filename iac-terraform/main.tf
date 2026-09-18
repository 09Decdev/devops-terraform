terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  description = "Vung dat ly cua toan bo tai nguyen"
  type        = string
  default     = "ap-southeast-2"
}

variable "instance_type" {
  description = "Kich thuowc may EC2"
  type        = string
  default     = "t3.micro"
}

variable "my_IP" {
  description = "IP duoc phep truy cap vao may EC2"
  type        = string
}

provider "aws" {
  region = var.region
}

# data source = "đọc thứ CÓ SẴN trên AWS" (khác resource = "tạo mới")
# default VPC đã tồn tại sẵn trong tài khoản -> chỉ việc tra cứu ID của nó
data "aws_vpc" "default" {
  default = true
}

resource "aws_instance" "example" {
  ami           = "ami-048cdccbe32bcb9a8"
  instance_type = var.instance_type

  user_data                   = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable --now nginx
    echo "<h1>May nay do Terraform sinh ra tu cat!</h1>" > /usr/share/nginx/html/index.html
  EOF
  user_data_replace_on_change = true


  # 2 dòng này "lắp" key và SG vào instance:
  key_name               = aws_key_pair.learn_terraform_key.key_name
  vpc_security_group_ids = [aws_security_group.learn_terraform_sg.id]

  tags = {
    Name = "ExampleInstance"
  }
}

resource "aws_key_pair" "learn_terraform_key" {
  key_name = "learn_terraform_key"
  # Terraform KHÔNG hiểu "~" phải viết đường dẫn tuyệt đối đầy đủ:
  public_key = file("/home/nguyenhungvy09/.ssh/devops-learn.pub")
}

resource "aws_security_group" "learn_terraform_sg" {
  name        = "learn-terraform-sg"
  description = "SG for learning"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_IP}/32"]
  }

  ingress {
    description = "http"
    from_port   = 80 # ← web port
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ← cả thế giới được xem web — khác SSH!
  }
  ingress {
    description = "MinIO S3 API - trinh duyet lay anh"
    from_port   = 19000
    to_port     = 19000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # doc anh -> cong khai nhu http
  }


  egress {
    description = "all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "learn-terraform"
  }
}

output "public_IP" {
  description = "IP cong khai de truy cap web va SSH"
  value       = aws_instance.example.public_ip
}

output "security_group_id" {
  description = "ID cua SG dang dung"
  value       = aws_security_group.learn_terraform_sg.id
}