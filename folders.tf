# Part 9: folder structure. raw/ and processed/ already exist (created in
# Lab 2.1); this lab adds the remaining three prefixes.

resource "aws_s3_object" "curated_folder" {
  bucket  = data.aws_s3_bucket.data_lake.id
  key     = var.curated_prefix
  content = ""
}

resource "aws_s3_object" "temp_folder" {
  bucket  = data.aws_s3_bucket.data_lake.id
  key     = var.temp_prefix
  content = ""
}

resource "aws_s3_object" "archive_folder" {
  bucket  = data.aws_s3_bucket.data_lake.id
  key     = var.archive_prefix
  content = ""
}
