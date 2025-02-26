resource "aws_instance" "backend" {
  ami           = "ami-053a45fff0a704a47"  # Update with your AMI
  instance_type = "t3.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id = data.aws_subnet.subnet-lab-1.id
  user_data     = <<-EOF
                #!/bin/bash
                sudo yum install -y httpd
                sudo systemctl start httpd
                echo "Hello World from $(hostname -f)" > /var/www/html/index.html
                EOF
  tags = {
    Name = "mtls-backend-server"
  }
}
