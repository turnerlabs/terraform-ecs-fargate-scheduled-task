/*
 * variables.tf
 * Common variables to use in various Terraform files (*.tf)
 */

# The AWS region to use for the dev environment's infrastructure
# Currently, Fargate is only available in `us-east-1`.
variable "region" {
  default = "us-east-1"
}

# Tags for the infrastructure
variable "tags" {
  type = "map"
}

# The application's name
variable "app" {}

# The environment that is being built
variable "environment" {}

# The VPC to use for the Fargate cluster
variable "vpc" {}

# The private subnets, minimum of 2, that are a part of the VPC(s)
variable "private_subnets" {}

# The public subnets, minimum of 2, that are a part of the VPC(s)
variable "public_subnets" {}

# locals

locals {
  namespace = "${var.app}-${var.environment}"
  log_group = "/fargate/task/${local.namespace}"
}
