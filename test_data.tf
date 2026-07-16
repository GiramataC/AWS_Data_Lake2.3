# Part 12: test data upload.

resource "aws_s3_object" "test_customers" {
  count = var.upload_test_data ? 1 : 0

  bucket       = data.aws_s3_bucket.data_lake.id
  key          = "${var.raw_prefix}test_customers.csv"
  source       = "${path.module}/sample_data/test_customers.csv"
  etag         = filemd5("${path.module}/sample_data/test_customers.csv")
  content_type = "text/csv"
  tags         = var.tags
}
