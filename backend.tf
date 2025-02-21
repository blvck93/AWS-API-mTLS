terraform {
  backend "s3" {
    bucket = "terraformstatebucket99993"
    key    = "terraform/state"
    region = "us-east-1"  # Specify your AWS region
  }
}