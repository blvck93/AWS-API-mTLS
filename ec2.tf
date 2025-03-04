resource "aws_instance" "backend" {
  ami           = "ami-053a45fff0a704a47"  # Update with your AMI
  instance_type = "t3.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id = data.aws_subnet.subnet-lab-1.id
  user_data     = <<-EOF
                #!/bin/bash
                sudo yum install -y httpd php php-cli php-common php-mbstring php-xml
                sudo systemctl start httpd
                
                echo '<?php foreach (getallheaders() as $name => $value) { echo "$name: $value<br>"; } ?>' > /var/www/html/index.php
                
                sudo systemctl restart httpd
                EOF


  tags = {
    Name = "mtls-backend-server"
  }
}
