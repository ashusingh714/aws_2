provider "aws"{
    profile = "ashuaws"
    region  = "ap-south-1"
}


resource "aws_security_group" "allow_nfs" {
  name        = "allow_nfs"
  description = "Allow Web server traffic with efs file system"


  ingress {
    description = "Allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "Allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
  description = "NFS"
  from_port   = 2049
  to_port     = 2049
  protocol    = "tcp"
  cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_nfs"
  }
}

resource "aws_instance" "efs_vol" {
 depends_on = [
		aws_security_group.allow_nfs,
                                     ]
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name = "iamashu"
  security_groups = [ "allow_nfs" ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Ashutosh/Downloads/iamashu.pem")
    host     = aws_instance.efs_vol.public_ip
  }


  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd   php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }


  tags = {
    Name = "ashu123"
  }
}

resource "aws_efs_file_system" "file" {
  depends_on = [  aws_instance.efs_vol,]
  creation_token = "nfs_file"

  tags = {
    Name = "nfs_file"
  }
}

resource "aws_efs_mount_target" "mounting" {
  depends_on  = [aws_efs_file_system.file, ]
  file_system_id = aws_efs_file_system.file.id
  subnet_id =  aws_instance.efs_vol.subnet_id
  security_groups = ["${aws_security_group.allow_nfs.id}"]
}

output "os_public_ip" {
  value = aws_instance.efs_vol.public_ip
}

resource "null_resource" "local"  {
depends_on = [
    aws_efs_mount_target.mounting,
  ]
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Ashutosh/Downloads/iamashu.pem")
    host     = aws_instance.efs_vol.public_ip
  }


provisioner "remote-exec" {
    inline = [
      "sudo echo ${aws_efs_file_system.file.dns_name}:/var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
      "sudo mount  ${aws_efs_file_system.file.dns_name}:/  /var/www/html",
      "sudo git clone https://github.com/ashusingh714/aws_2.git  /var/www/html/"
      
    ]
  }
}

resource "null_resource" "gitlocal"  {
  depends_on = [  null_resource.local,  ]
	provisioner "local-exec" {
	    command = "git clone https://github.com/ashusingh714/aws_2.git     C:/Users/Ashutosh/Desktop/cloud/gitfolder1/"


  	}
}


resource "aws_s3_bucket" "bucket" {
                depends_on=[
                                  null_resource.gitlocal,
                                     ]
                bucket = "ashu1264"
                acl = "public-read"
}


resource  "aws_s3_bucket_object" "files"{
               depends_on= [
                                aws_s3_bucket.bucket,
               ]
               bucket = "ashu1264"
               key = "Mountain.jpg"
               source =  "C:/Users/Ashutosh/Desktop/cloud/gitfolder1/New.jpg"
               acl =  "public-read"
               content_type= "image/jpg"
              
}
variable "bucket1" {
	default = "s3-"
}
locals {
s3_origin_id = "${var.bucket1}${aws_s3_bucket.bucket.id}"
}




resource "aws_cloudfront_distribution" "s3_distribution" {
	origin {
	domain_name = "${aws_s3_bucket.bucket.bucket_regional_domain_name}"
	origin_id   = "${local.s3_origin_id}"
	}


  	enabled             = true
  	is_ipv6_enabled     = true
  	comment             = "Web server"
        
        
  
	default_cache_behavior {
    		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = "${local.s3_origin_id}"


    		forwarded_values {
      			query_string = false


	      		cookies {
        			forward = "none"
      			}
    		}


    	viewer_protocol_policy = "allow-all"
    
 	}
	
	restrictions {
    		geo_restriction {
      			restriction_type = "none"
    		}
  	}


	viewer_certificate {
    		cloudfront_default_certificate = true
  	}


	depends_on=[
		aws_s3_bucket_object.files
	]


	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("C:/Users/Ashutosh/Downloads/iamashu.pem")
		host = aws_instance.efs_vol.public_ip
	}
	provisioner "remote-exec" {
		inline = [
				"sudo su << EOF",
"echo \"<img src='https://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.files.key }'>\" >> /var/www/html/index.html",
"EOF"
			]
	}
	
}
resource "null_resource" "nulllocal1" {


	depends_on = [
		aws_cloudfront_distribution.s3_distribution
	]


	provisioner "local-exec" {
		command = "start chrome  ${aws_instance.efs_vol.public_ip}"
	}
}








































