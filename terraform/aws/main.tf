terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.15"
    }
  }

  backend "remote" {
    organization = "morriscloud"

    workspaces {
      name = "static-website-playground-aws-terraform"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Project = "Static Website Playground"
    }
  }
}

provider "cloudflare" {
}

locals {
  site_domain = "aws-terraform-static.morriscloud.com"
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.this.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

  }
}

resource "aws_s3_bucket" "this" {
  bucket        = local.site_domain
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.this.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_acl" "this" {
  bucket = aws_s3_bucket.this.bucket
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.this.bucket
  key          = "index.html"
  source       = "index.html"
  etag         = filemd5("index.html")
  content_type = "text/html"
}

data "cloudflare_zone" "this" {
  name = "morriscloud.com"
}

resource "cloudflare_record" "this" {
  zone_id = data.cloudflare_zone.this.zone_id
  name    = local.site_domain
  value   = aws_s3_bucket_website_configuration.this.website_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
}
