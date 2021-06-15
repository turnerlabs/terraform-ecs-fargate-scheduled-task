terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 2.23.0"
    }
  }
  required_version = ">= 0.13"
}
