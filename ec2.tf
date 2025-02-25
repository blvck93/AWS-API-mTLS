resource "aws_instance" "backend" {
  ami           = "ami-053a45fff0a704a47"  # Update with your AMI
  instance_type = "t3.micro"
  security_groups = [aws_security_group.ec2_sg.name]
  subnet_id = data.aws_subnet.subnet-lab-1.id
  user_data     = <<-EOF
                #!/bin/bash
                sudo yum install -y httpd
                sudo systemctl start httpd
                EOF
  tags = {
    Name = "mtls-backend-server"
  }
}
