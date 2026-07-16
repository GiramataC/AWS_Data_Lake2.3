terraform {
  required_version = ">= 1.10.0" # native S3 backend locking (use_lockfile) needs this

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
