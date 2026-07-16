# Remote state so both local runs and GitHub Actions share one source of
# truth. Terraform backend blocks can't reference variables/data sources,
# so this is a literal value - bucket is terraform-state-lab2-3-<account_id>,
# created and hardened (versioning, SSE, public-access-block) in ci_cd.tf.
terraform {
  backend "s3" {
    bucket       = "terraform-state-lab2-3-463470950988"
    key          = "s3-datalake-foundation/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
