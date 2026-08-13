variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
  default     = "hrms-terraform-test-bucket"
}

variable "app_secret_value" {
  description = "Placeholder value stored in Secrets Manager and injected into the ECS task"
  type        = string
  default     = "change-me"
  sensitive   = true
}
