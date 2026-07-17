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
    #
    # The trailing "*" after owner/repo accounts for GitHub's immutable-ID
    # subject claim format (repo:owner@ownerId/repo@repoId:...) as well as
    # the plain owner/repo format - confirmed via CloudTrail that this repo
    # actually sends "repo:GiramataC@176739852/AWS_Data_Lake2.3@1302964022:
    # ref:refs/heads/main", not the plain form the first version of this
    # policy assumed (which is why the first CI run got AccessDenied).
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.github_owner}*/${local.github_repo_name}*:pull_request",
        "repo:${local.github_owner}*/${local.github_repo_name}*:ref:refs/heads/main",
        "repo:${local.github_owner}*/${local.github_repo_name}*:environment:production",
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
      # aws_s3_bucket resource/data-source refresh reads many sub-configs
      # (cors, website, replication, acceleration, object lock, tagging,
      # ...) regardless of whether this project's config touches them -
      # s3:Get* avoids repeated one-off AccessDenied failures for whichever
      # sub-config the provider decides to read next, still scoped to only
      # this one bucket ARN rather than granted account-wide.
      "s3:Get*",
      "s3:ListBucket",
      "s3:PutBucketPolicy",
      "s3:PutBucketLogging",
      "s3:PutLifecycleConfiguration",
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
      # Same s3:Get* rationale as DataLakeBucketReadWrite above - these two
      # buckets are fully owned by this project (created and configured
      # here), so the wildcard read is paired with full write control
      # rather than just a handful of enumerated write actions.
      "s3:Get*",
      "s3:ListBucket",
      "s3:CreateBucket",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketPolicy",
      "s3:PutBucketTagging",
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

  # data.aws_iam_openid_connect_provider looks the provider up by URL, which
  # requires listing all providers first (no resource-level scoping for
  # List) before it can read the matched one's attributes.
  statement {
    sid       = "ListGithubOidcProvider"
    effect    = "Allow"
    actions   = ["iam:ListOpenIDConnectProviders"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadGithubOidcProvider"
    effect    = "Allow"
    actions   = ["iam:GetOpenIDConnectProvider"]
    resources = [data.aws_iam_openid_connect_provider.github.arn]
  }

  # This role and its inline policy are themselves managed resources in
  # this config (aws_iam_role.github_actions_deploy /
  # aws_iam_role_policy.github_actions_deploy below), so every plan/apply
  # refreshes them via these calls - scoped to only this one role, not IAM
  # roles in general.
  statement {
    sid    = "SelfManageDeployRole"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = [aws_iam_role.github_actions_deploy.arn]
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
