variable "project_name" {
  description = "This is your project name"
  type        = string
}

variable "region" {
  description = "AWS region where resources will be provisioned"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "env" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "azs" {
  description = "List of Availability Zones to deploy resources into"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "app_subnets" {
  description = "List of application subnet CIDR blocks"
  type        = list(string)
}

variable "db_subnets" {
  description = "List of database subnet CIDR blocks"
  type        = list(string)
}

# App database credentials
variable "db_username" {
  description = "Username for the application database"
  sensitive   = true
  type        = string
}

variable "db_password" {
  description = "Password for the application database"
  sensitive   = true
  type        = string
}

variable "app_database" {
  description = "Name of the application database"
  sensitive   = true
  type        = string
}

variable "app_config_filepath" {
  description = "Path to the app tier user data template file"
  type        = string
  default     = "./server-boot/app-tier-userdata.tpl"
}

variable "web_config_filepath" {
  description = "Path to the configuration file to bootstrap the app tier instance"
  type        = string
  default     = "./server-boot/web-tier-userdata.tpl"
}

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
  default     = "bughunter.life"
}

variable "additional_acm_domain_name" {
  description = "Additional ACM domain name for SSL certificates"
  type        = string
}

variable "additional_domain_name" {
  description = "Additional domain name for the application"
  type        = string
}

variable "waf_name" {
  description = "Name of the WAF (Web Application Firewall) to be created"
  type        = string
}

variable "secret_manager_name" {
  description = "Name of the AWS Secrets Manager secret for sensitive data"
  type        = string
}

variable "instance_type" {
  description = "Type of EC2 instance for the application"
  type        = string
  default     = "t2.medium"
}

variable "web_tier_lb" {
  description = "Name of the web tier (internet facing) load balancer"
  type        = string
}

variable "app_tier_lb" {
  description = "Name of the app tier load balancer"
  type        = string
}

variable "public_key_path" {
  description = "Path to public key file"
  type        = string
}