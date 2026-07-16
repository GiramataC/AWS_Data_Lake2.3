locals {
  data_lake_bucket_name = var.data_lake_bucket_name != "" ? var.data_lake_bucket_name : "data-lake-prod-${data.aws_caller_identity.current.account_id}"
  log_bucket_name       = var.log_bucket_name != "" ? var.log_bucket_name : "data-lake-prod-logs-${data.aws_caller_identity.current.account_id}"
  tf_state_bucket_name  = var.tf_state_bucket_name != "" ? var.tf_state_bucket_name : "terraform-state-lab2-3-${data.aws_caller_identity.current.account_id}"

  data_lake_role_arns = [
    data.aws_iam_role.data_engineer.arn,
    data.aws_iam_role.glue_service.arn,
    data.aws_iam_role.redshift_iam.arn,
  ]
}
