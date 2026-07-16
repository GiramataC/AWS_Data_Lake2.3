# Part 10: lifecycle policies for cost optimization.

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = data.aws_s3_bucket.data_lake.id

  # Policy 1: processed/ - Glacier after 90 days, Deep Archive after 180 days.
  rule {
    id     = "processed-data-tiering"
    status = "Enabled"

    filter {
      prefix = var.processed_prefix
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }
  }

  # Policy 2: temp/ - delete after 1 day.
  rule {
    id     = "temp-data-expiration"
    status = "Enabled"

    filter {
      prefix = var.temp_prefix
    }

    expiration {
      days = 1
    }
  }

  # Policy 3: archive/ - Deep Archive after 30 days, delete after 7 years.
  rule {
    id     = "archive-data-tiering"
    status = "Enabled"

    filter {
      prefix = var.archive_prefix
    }

    transition {
      days          = 30
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555
    }
  }
}
