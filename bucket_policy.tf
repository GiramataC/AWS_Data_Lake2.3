# Part 5: bucket policy on the existing data lake bucket.
#
# The "allow IAM roles only" rule from the lab spec is implemented as explicit
# grants for the three named roles rather than a blanket
# `Deny * unless Principal in [...]`. A hard denylist-of-everyone-else would
# also lock out this account's own Terraform execution role and any other
# legitimate consumer already relying on its own IAM identity policy (e.g.
# DataSyncS3Role from Lab 2.1) - a real risk of a management lockout on a
# live account, not just a lab inconvenience. The two Deny statements below
# (HTTPS + encryption enforcement) are the safe, standard part of this
# pattern and apply regardless of principal.

data "aws_iam_policy_document" "data_lake_bucket_policy" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [data.aws_s3_bucket.data_lake.arn, "${data.aws_s3_bucket.data_lake.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "DenyUnencryptedObjectUploads"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${data.aws_s3_bucket.data_lake.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256"]
    }
  }

  statement {
    sid    = "AllowDataLakeRolesBucketLevelAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.data_lake_role_arns
    }

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [data.aws_s3_bucket.data_lake.arn]
  }

  statement {
    sid    = "AllowDataLakeRolesObjectAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.data_lake_role_arns
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
    ]
    resources = ["${data.aws_s3_bucket.data_lake.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "data_lake" {
  bucket = data.aws_s3_bucket.data_lake.id
  policy = data.aws_iam_policy_document.data_lake_bucket_policy.json
}
