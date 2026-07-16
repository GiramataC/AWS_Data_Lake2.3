# Part 8: audit trail covering bucket/IAM changes (management events, on by
# default) plus object-level S3 actions on the data lake bucket (data events).

resource "aws_cloudtrail" "data_lake" {
  name           = var.cloudtrail_name
  s3_bucket_name = aws_s3_bucket.logs.id
  s3_key_prefix  = "cloudtrail"

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${data.aws_s3_bucket.data_lake.arn}/"]
    }
  }

  tags = var.tags

  depends_on = [aws_s3_bucket_policy.logs]
}
