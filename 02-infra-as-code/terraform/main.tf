provider "aws" {
  region  = var.aws_region
  profile = "iamadmin-gen"  # ← Use this profile
}

