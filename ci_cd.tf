# CI/CD: lets GitHub Actions in var.github_repo plan/apply this exact
# Terraform project via OIDC (no long-lived AWS keys stored in GitHub).
#
# The OIDC provider (token.actions.githubusercontent.com) already exists in
# this account - created out-of-band for Lab 1.1's IAM-Lab CI - so it's
# referenced here as a data source rather than recreated.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scoped to: PR-triggered plan runs, push-to-main runs, and the
    # environment-gated apply job (environment:production requires a
    # reviewer to approve in the GitHub UI before this condition is met).
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:pull_request",
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "GitHubActions-DataLakeDeployRole"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = var.tags
}

# Least-privilege for exactly the resources this project manages, rather
# than reusing a broad managed policy. The object-level statements below
# necessarily wildcard the trailing "/*" (there's no non-wildcard way to
# grant "objects under this bucket" - same rationale as Lab 2.1's
# datasync_s3_access policy) and CloudTrail's management actions have no
# resource-level ARN to scope to in the first place.
#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid    = "DataLakeBucketReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:GetBucketLogging",
      "s3:PutBucketLogging",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:ListBucket",
    ]
    resources = [data.aws_s3_bucket.data_lake.arn]
  }

  statement {
    sid    = "DataLakeObjectReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
    ]
    resources = ["${data.aws_s3_bucket.data_lake.arn}/*"]
  }

  statement {
    sid    = "LogsAndStateBucketsFullManagement"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:GetBucketAcl",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.logs.arn,
      aws_s3_bucket.tf_state.arn,
    ]
  }

  statement {
    sid    = "LogsAndStateObjectReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.logs.arn}/*",
      "${aws_s3_bucket.tf_state.arn}/*",
    ]
  }

  # CloudTrail has no resource-level ARN targeting for most of these
  # actions (AWS enforces via the account/region, not a resource policy),
  # so this is scoped by action set instead - still far narrower than "*".
  statement {
    sid    = "CloudTrailManagement"
    effect = "Allow"
    actions = [
      "cloudtrail:CreateTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:DeleteTrail",
      "cloudtrail:GetTrail",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:DescribeTrails",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:GetEventSelectors",
      "cloudtrail:StartLogging",
      "cloudtrail:StopLogging",
      "cloudtrail:AddTags",
      "cloudtrail:RemoveTags",
      "cloudtrail:ListTags",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadDataLakeIamRoles"
    effect    = "Allow"
    actions   = ["iam:GetRole"]
    resources = local.data_lake_role_arns
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "DataLakeCiCdDeployAccess"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

# Remote state backend (Part: CI/CD needs persistent state across runs).
# Access logging is skipped here for the same reason as the "logs" bucket
# below: it's pure infrastructure holding Terraform state, not user data,
# and logging it would mean provisioning yet another hardened bucket just
# to log access to state files - not proportionate for a teaching lab.
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "tf_state" {
  bucket = local.tf_state_bucket_name

  tags = merge(var.tags, {
    Name    = local.tf_state_bucket_name
    Purpose = "TerraformState"
  })
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
