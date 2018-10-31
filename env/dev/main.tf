terraform {
  required_version = ">= 0.11.0"

  backend "s3" {
    region  = "us-east-1"
    profile = ""
    bucket  = ""
    key     = "dev.terraform.tfstate"
  }
}

# The AWS Profile to use
variable "aws_profile" {}

provider "aws" {
  version = ">= 1.39.0"
  region  = "${var.region}"
  profile = "${var.aws_profile}"
}

# output

# Command to set the AWS_PROFILE
output "aws_profile" {
  value = "${var.aws_profile}"
}
