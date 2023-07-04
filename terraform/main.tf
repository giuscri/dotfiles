terraform {
  cloud { # You MUST export `TF_CLOUD_ORGANIZATION` for this to work.
    workspaces {
      name = "dotfiles"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "main" {
  bucket = "com.github.giuscri.dotfiles"
}

resource "aws_iam_user" "main" {
  name = "dotfiles"
}

resource "aws_iam_user_policy_attachment" "main" {
  user       = aws_iam_user.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_access_key" "main" {
  user = aws_iam_user.main.name
}

output "access_key_id" {
  value = aws_iam_access_key.main.id
}

output "secret_access_key" {
  value = aws_iam_access_key.main.secret
  sensitive = true
}
