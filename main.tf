terraform {
  backend "s3" {
    encrypt = false
  }
  required_version = ">= 1.1.0"
  required_providers {
    aws = "~> 4.0"
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name

  tags = {
    Name = "Mudassit test - delete"
    #Environment = "Dev"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example_sse" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "example_owner" {
  bucket = aws_s3_bucket.example.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "exampl_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.example_owner]
  bucket     = aws_s3_bucket.example.id
  acl        = "private"
}

resource "aws_s3_bucket_policy" "example_bucket_policy" {
  bucket = aws_s3_bucket.example.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect" : "Deny",
      "Principal" : "*",
      "Action" : "s3:*",
      "Resource" : [
        "arn:aws:s3:::${aws_s3_bucket.example.id}",
        "arn:aws:s3:::${aws_s3_bucket.example.id}/*"
      ],
      "Condition" : {
        "Bool" : {
          "aws:SecureTransport" : "false"
        }
      }
    }
  ]
}
EOF
}

resource "aws_s3_bucket_public_access_block" "bucketsecpolpublic" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  #avoid race condition AWS bug
  depends_on = [
    aws_s3_bucket_policy.example_bucket_policy
  ]
}

output "bucket_info" {
  value = aws_s3_bucket.example.tags
}

resource "aws_iam_role" "AccountBRole" {
  name = "test_s3_role"
  permissions_boundary = "arn:aws:iam::727349431507:policy/ADSK-Boundary"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          "AWS": "arn:aws:iam::727349431507:role/AccountARole"
        }
      },
      {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::mudassir-test-tf-3/*"
        }
    ]
  })

  tags = {
    tag-key = "test-cross-account"
  }
}