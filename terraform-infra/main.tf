# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = "<>"
  secret_key = "<>"
}

# backend
# general state - need to split up into env specific state
terraform {
  backend "s3" {
    bucket  = "my-test-generic-tf-state-bucket"
    key     = "global/s3/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

# terraform {
#   backend "s3" {}
# }


# test resources
resource "aws_instance" "ec2-server" {
  for_each      = var.env
  ami           = "ami-0bb84b8ffd87024d8"
  instance_type = "t2.micro"
  tags = {
    Name = "${each.key}-server"
  }
}
