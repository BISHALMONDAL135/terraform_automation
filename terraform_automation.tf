provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAW75GPH5TAIOIDUA5"
  secret_key = "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"
}
#Creating KeyPair

resource "aws_key_pair" "mykey" {
  key_name   = "my-key-1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
}

#Creating SecurityGroup which allows Port 80 and Port 22
resource "aws_security_group" "securitygrp-1" {
  name        = "my-secgrp-1"
  description = "Allow Port 22 and Port 80 for all IPs"

  ingress {
    description = "TCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "my-SecGrptera"
  }
}

#Launching Instance with the Security Group and KeyPair created earlier

resource "aws_instance" "my_teraos" {
  ami = "ami-0b44050b2d893d5f7"
  instance_type = "t2.micro"
  key_name = "my-key-1"
  availability_zone = "ap-south-1a"
  security_groups = ["my-secgrp-1"]

  tags = {
    Name = "My_auto_Webserver"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  connection {
    type = "ssh"
    user = "ec2-user"
    password = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
    host = aws_instance.my_teraos.public_ip
  }

}

#Creating EBS Volume
resource "aws_ebs_volume" "my_ebs" {
  availability_zone = "ap-south-1a"
  size = 1

  tags = {
    Name = "Mytera_Vol"
  }
}
#Attaching EBS Volume
resource "aws_volume_attachment" "my_ebs_att" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.my_ebs.id
  instance_id = aws_instance.my_teraos.id
  force_detach = true
}

#Creating S3 Bucket with an image as its object and also give it public access
resource "aws_s3_bucket" "mytera-s3-bucket" {
  bucket = "mytera-s3-bucket"
  acl    = "private"
  region = "ap-south-1"

  tags = {
    Name = "Mytera_S3_Bucket"
  }
}

locals {
  s3_origin_id = "my-s3-origin"
}

resource "aws_s3_bucket_object" "mytera-s3-bucket" {
  bucket = "mytera-s3-bucket"
  key    = "image.jpg"
  source = "C:/Users/KIIT/Desktop/tera/test/images.jpg"
}

resource "aws_s3_bucket_public_access_block" "mys3_public" {
  bucket = "mytera-s3-bucket"

  block_public_acls   = false
  block_public_policy = false
}

#Creating a CDN 
resource "aws_cloudfront_distribution" "mytera_cloudfront_distr" {
  origin {
    domain_name = aws_s3_bucket.mytera-s3-bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    custom_origin_config {
      http_port = 80
      https_port = 80
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  
  enabled = true

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

#Mounting the EBS volume
resource "null_resource" "mountingvol" {

  depends_on = [
    aws_volume_attachment.my_ebs_att,
  ]

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdd",
      "sudo mount /dev/xvdd /var/www/html",
      "sudo rm -rf /var/www/html",
      "sudo git clone https://github.com/BISHALMONDAL135/terraform_automation.git /var/www/html",
    ]
  } 

connection {
    type = "ssh"
    user = "ec2-user"
    password = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
    host = aws_instance.my_teraos.public_ip
  }
}

resource "null_resource" "Testing" {

  depends_on = [
    null_resource.mountingvol,
  ]
  provisioner "local-exec" {
    command = "firefox ${aws_instance.my_teraos.public_ip}"
  }

}

output "az" {
  value = aws_instance.my_teraos.availability_zone
}

output "ip" {
  value = aws_instance.my_teraos.public_ip
}




































