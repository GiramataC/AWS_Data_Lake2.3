output "data_lake_bucket_name" {
  description = "Name of the (pre-existing) data lake bucket this lab hardens"
  value       = data.aws_s3_bucket.data_lake.id
}

output "data_lake_bucket_arn" {
  description = "ARN of the data lake bucket"
  value       = data.aws_s3_bucket.data_lake.arn
}

output "log_bucket_name" {
  description = "Name of the S3 access-log / CloudTrail destination bucket"
  value       = aws_s3_bucket.logs.id
}

output "cloudtrail_arn" {
  description = "ARN of the data lake audit trail"
  value       = aws_cloudtrail.data_lake.arn
}

output "folder_prefixes" {
  description = "Full folder structure in the data lake bucket"
  value = {
    raw       = var.raw_prefix
    processed = var.processed_prefix
    curated   = var.curated_prefix
    temp      = var.temp_prefix
    archive   = var.archive_prefix
  }
}

output "data_lake_role_arns" {
  description = "IAM roles granted access via the data lake bucket policy"
  value       = local.data_lake_role_arns
}
