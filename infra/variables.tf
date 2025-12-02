variable "aws_region" { default = "eu-central-1" }
variable "project_name" { default = "planning-poker" }
variable "s3_bucket_name" { type = string }
variable "lambda_zip_path" { default = "lambda.zip" } # path relative to infra/
