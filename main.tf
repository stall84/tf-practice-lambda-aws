
terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = "~> 1.0"

}

provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "lambda_bucket_name" {
  prefix = "ms-simple-api"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

##########---------###########
# Actions to archive/zip lambda per aws reqs
##########---------###########

# Archive File type named 'init' will (describe) how our source code is zipped for aws
data "archive_file" "init" {

  type = "zip"

  source_dir  = path.module
  output_path = "/tmp/ms-simple-api.zip"

  excludes = [
    ".git",
    ".gitattributes",
    ".gitignore",
    ".idea",
    ".jshintrc",
    ".terraform",
    ".terraform.lock.hcl",
  ]
}

resource "aws_s3_object" "lambda_ms-simple" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "ms-simple-api.zip"
  source = data.archive_file.init.output_path

  etag = "testing"
}
