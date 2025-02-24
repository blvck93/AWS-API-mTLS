resource "aws_instance" "backend" {
  ami           = "ami-0c55b159cbfafe1f0"  # Update with your AMI
  instance_type = "t3.micro"
  security_groups = [aws_security_group.ec2_sg.name]
  user_data     = <<-EOF
                #!/bin/bash
                echo "Thumbprint: $THUMBPRINT" > /var/www/html/index.html
                EOF
  tags = {
    Name = "mtls-backend-server"
  }
}
