provider "aws" {
    region = "ap-south-1"
     access_key = "AKIA4EDZYOFORSYHZQWF"
     secret_key = "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"
  
}

resource "aws_s3_bucket" "my_s3_bucket" {
    bucket = "terraform-bucket-mumbai-1-testing"
  
}

resource "aws_iam_user" "my_iam_user" {
    count = 2
    name = "test_user_terraform.${count.index}"
  
}

#EC2
resource "aws_instance" "my_ec2" {
    ami = "ami-0607784b46cbe5816"
    instance_type = "t2.micro"
    key_name = "aws"
    tags = {
        Name="Terraform_EC2"
    }
  
}
resource "aws_security_group" "my_sg" {
  name        = "allow_http"
  description = "Allow http and ssh inbound traffic"


  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
 
  }
ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_http_ssh"
  }
}

#SSH Key
resource "tls_private_key" "web_private_key" {
    algorithm   =  "RSA"
    rsa_bits    =  4096
}
resource "local_file" "private_key" {
    content         =  tls_private_key.web_private_key.private_key_pem
    filename        =  "webserver_key.pem"
    file_permission =  0400
}
resource "aws_key_pair" "task_key" {
  key_name   = "aws_key_terraform"
  public_key = tls_private_key.web_private_key.public_key_openssh
}


#Launch EC2 instance with Http web-server using SG & SSH key
resource "aws_instance" "web_instance" {
  ami           = "ami-0607784b46cbe5816"
  instance_type = "t2.micro" 
  key_name = "aws_key_terraform"
  availability_zone="ap-south-1a"
  security_groups= ["${aws_security_group.my_sg.name}"]


 connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.web_instance.public_ip
        port    = 22
        private_key = tls_private_key.web_private_key.private_key_pem
    }
   provisioner "remote-exec" {
        inline  = [
        "sudo yum update -y",
		"sudo yum install httpd -y",
		"sudo yum install git -y",
        "sudo systemctl start httpd",
        "sudo systemctl enable httpd",
       "sudo bash -c 'echo This is my first web-server deployment via Terraform!! > /var/www/html/index.html' "
            
	]
    }
  


  tags = {
    Name = "webserver"
  }
}

#Create EBS Volume
resource "aws_ebs_volume" "web_2GB_volume" {
  availability_zone = aws_instance.web_instance.availability_zone
  size              = 2


  tags = {
    Name = "web_ebs"
  }
}

#Attaching EBS volume
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.web_2GB_volume.id
  instance_id = aws_instance.web_instance.id
  force_detach =true 
  depends_on=[ aws_ebs_volume.web_2GB_volume]
}

#Run nginx on the Docker Container
resource "aws_instance" "docker" {
  ami           = "ami-0607784b46cbe5816"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1b"
  key_name = "aws"
  security_groups= ["${aws_security_group.my_sg.name}"]

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing docker"
  sudo yum update -y
  sudo yum install docker.io -y
  sudo systemctl enable --now docker
  docker --version
  echo "*** Completed Installation of docker"
  sudo docker run -it --name my_nginx -p80:80 -d 91197/nginx_custom:1.0
  EOF

  tags = {
    Name = "Docker_Terraform"
  }
}
