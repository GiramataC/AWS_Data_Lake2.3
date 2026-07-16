# References to infrastructure created in Labs 1.1 and 2.1.
# This lab hardens the existing data lake bucket rather than recreating it -
# it was already provisioned (as a Lab 1.3 prerequisite) by Lab 2.1's Terraform.

data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "data_lake" {
  bucket = local.data_lake_bucket_name
}

data "aws_iam_role" "data_engineer" {
  name = var.data_engineer_role_name
}

data "aws_iam_role" "glue_service" {
  name = var.glue_service_role_name
}

data "aws_iam_role" "redshift_iam" {
  name = var.redshift_role_name
}
