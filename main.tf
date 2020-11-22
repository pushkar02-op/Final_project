provider "aws" {
region = "ap-south-1"
profile = "pushkar1"
}
variable "mykey" {
	type = string
	default = "mykey121"
}


resource "aws_vpc" "myvpc1" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = "true"

  tags = {
    Name = "MyVpc"
  }
}

resource "aws_subnet" "public_subnet" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id = aws_vpc.myvpc1.id

  tags = {
    Name = "Internet gateway"
  }
}


resource "aws_route_table" "my_route_table1" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id = aws_vpc.myvpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  
  tags = {
    Name = "Routing Table"
  }
}

resource "aws_route_table_association" "Route_association" {
  depends_on = [
    aws_route_table.my_route_table1,
  ]
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.my_route_table1.id
}



resource "aws_security_group" "Website_sg" {

  name        = "Website_sg"
  description = "Allow Tcp $ Ssh inbound traffic"
  vpc_id      = aws_vpc.myvpc1.id
  

  ingress {
    description = "Ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "http"
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
    Name = "allow_SSh_http"
  }
}

resource "aws_security_group" "MySql_sg" {
  name        = "MySq_sg"
  description = "Allow Website inbound traffic"
  vpc_id      = aws_vpc.myvpc1.id
  

  
 ingress {
    description = "Allow MySql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    
  }
 ingress {
    description = "Ssh"
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
    Name = "allow_MySql"
  }
}






resource "aws_instance" "inst" {
    depends_on = [
     aws_vpc.myvpc1,aws_security_group.Website_sg,
   ]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = var.mykey
  vpc_security_group_ids = [ aws_security_group.Website_sg.id]
  
   associate_public_ip_address = "true"
    availability_zone = "ap-south-1a"
    subnet_id = aws_subnet.public_subnet.id


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file    ("C:/Users/Lenovo/Desktop/mykey121.pem")
    host     = aws_instance.inst.public_ip
  }

  
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  
  tags = {
    Name = "pushkar"
  }
}

output "avail_zone" {
	value = aws_instance.inst.availability_zone
}

output "Vol_id" {
	value = aws_ebs_volume.myvol1.id
}

output "inst_id" {
	value = aws_instance.inst.id
}


resource "aws_ebs_volume" "myvol1" {
  availability_zone = aws_instance.inst.availability_zone
  size              = 1

 tags = {
    Name = "Pushkar_volume"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.myvol1.id
  instance_id = aws_instance.inst.id
  force_detach = true
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file    ("C:/Users/Lenovo/Desktop/mykey121.pem")
    host     = aws_instance.inst.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/pushkar02-op/College_Project.git /var/www/html/"
    ]
  }
}



resource "aws_instance" "mysql"{
   depends_on = [
    aws_vpc.myvpc1,aws_security_group.MySql_sg,
  ]
ami   = "ami-026669ec456129a70"
instance_type = "t2.micro"
vpc_security_group_ids = [ aws_security_group.MySql_sg.id]
subnet_id = aws_subnet.private_subnet.id
user_data = <<-EOF
#!/bin/bash
sudo yum update -y
sudo yum install mysql -y
EOF

tags = {
 Name = "MySqlOS"
  }
} 

# output "SQL_ip" {
# 	value = aws_instance.mysql.private.ip
# }
resource "null_resource" "nullremote2"  {

depends_on = [
    null_resource.nullremote3,
  ]
  

provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.inst.public_ip}"
  	}
}