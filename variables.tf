variable "aws_region" {
  description = "AWS region for the lab (must match Labs 1.1-1.3, 2.1 and 2.2)"
  type        = string
  default     = "eu-west-1"
}

variable "data_lake_bucket_name" {
  description = "Name of the existing data lake bucket (created in Lab 2.1). Leave blank to derive it from the account ID (data-lake-prod-<account_id>)."
  type        = string
  default     = ""
}

variable "log_bucket_name" {
  description = "Name of the S3 access-log bucket to create. Leave blank to derive it from the account ID (data-lake-prod-logs-<account_id>)."
  type        = string
  default     = ""
}

variable "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = "data-lake-audit-trail"
}

variable "data_engineer_role_name" {
  description = "Name of the DataEngineerRole created in Lab 1.1"
  type        = string
  default     = "DataEngineerRole"
}

variable "glue_service_role_name" {
  description = "Name of the GlueServiceRole created in Lab 1.1"
  type        = string
  default     = "GlueServiceRole"
}

variable "redshift_role_name" {
  description = "Name of the RedshiftIAMRole created in Lab 1.1"
  type        = string
  default     = "RedshiftIAMRole"
}

variable "raw_prefix" {
  description = "Prefix (folder) for immutable source data"
  type        = string
  default     = "raw/"
}

variable "processed_prefix" {
  description = "Prefix (folder) for cleaned datasets"
  type        = string
  default     = "processed/"
}

variable "curated_prefix" {
  description = "Prefix (folder) for analytics-ready data"
  type        = string
  default     = "curated/"
}

variable "temp_prefix" {
  description = "Prefix (folder) for temporary job files"
  type        = string
  default     = "temp/"
}

variable "archive_prefix" {
  description = "Prefix (folder) for long-term storage"
  type        = string
  default     = "archive/"
}

variable "upload_test_data" {
  description = "Whether to upload the sample test_customers.csv file to raw/ (Part 12)"
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repo (org/name) allowed to assume the CI/CD deploy role via OIDC"
  type        = string
  default     = "GiramataC/AWS_Data_Lake2.3"
}

variable "tf_state_bucket_name" {
  description = "Name of the S3 bucket holding this lab's remote Terraform state. Leave blank to derive it from the account ID (terraform-state-lab2-3-<account_id>)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to resources created by this lab"
  type        = map(string)
  default = {
    Project = "data-platform"
    Lab     = "2.3-s3-datalake-foundation"
  }
}
