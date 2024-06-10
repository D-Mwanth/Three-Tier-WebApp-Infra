# Set up terraform constraints
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.42.0"
    }
  }

  backend "s3" {
    bucket         = "3-tier-archit-bucket-by-daniel"
    key            = "backend/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "3-tier-archit-terra-lock"
  }
}

provider "aws" {
  region  = var.region
  profile = "webapp-terraform-user"
}

# Create VPC
module "vpc" {
  source         = "git@github.com:D-Mwanth/tf-custom-modules.git//vpc?ref=main"
  env            = var.project_name
  vpc_cidr_block = var.vpc_cidr_block
  azs            = var.azs
  public_subnets = var.public_subnets
  app_subnets    = var.app_subnets
  db_subnets     = var.db_subnets
}

# Create security groups
module "sg" {
  source           = "git@github.com:D-Mwanth/tf-custom-modules.git//sg?ref=main"
  vpc_id           = module.vpc.vpc_id
  app_subnets_cidr = var.app_subnets
}

# SSM vpc endpoints
module "system_manger_endpoints" {
  source            = "git@github.com:D-Mwanth/tf-custom-modules.git//ssm?ref=main"
  region            = var.region
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.app_subnets_ids
  security_group_id = module.sg.sysmanager_endpoints_sg
}

# IAM profile
module "iam" {
  source = "git@github.com:D-Mwanth/tf-custom-modules.git//iam?ref=main"
}

# Creating Key pair for instances
module "key" {
  source     = "git@github.com:D-Mwanth/tf-custom-modules.git//key?ref=main"
  public_key = var.public_key_path
}

# Database deployment
module "database" {
  source         = "git@github.com:D-Mwanth/tf-custom-modules.git//database?ref=main"
  db_sg_id       = module.sg.database_sg
  db_subnets_ids = module.vpc.db_subnets_ids
  db_username    = var.db_username
  db_password    = var.db_password

  env = var.env
}

# Create Secret Manager and store DB creds there for secure application retrival
module "secret_manager" {
  source       = "git@github.com:D-Mwanth/tf-custom-modules.git//secret-manager?ref=main"
  secret_name  = var.secret_manager_name
  app_database = var.app_database
  db_username  = module.database.database_credentials.username
  db_password  = module.database.database_credentials.password
  db_endpoint  = module.database.database_credentials.endpoint
  depends_on   = [module.database]
}

########## App Deploymnet ##############
########################################

# Internal (app tier) loadbalancer deployment
module "app_tier_lb" {
  source           = "git@github.com:D-Mwanth/tf-custom-modules.git//lb?ref=main" #/app_lb"
  vpc_id           = module.vpc.vpc_id
  lb_name          = var.app_tier_lb
  instance_tg_port = 4000
  security_group   = module.sg.internal_lb_sg
  subnets          = module.vpc.app_subnets_ids
  internal         = true
}

# Create Autoscaling group for app tier
module "app_tier_asg" {
  source        = "git@github.com:D-Mwanth/tf-custom-modules.git//asg?ref=main"
  tier_name     = "app-tier"
  instance_type = var.instance_type
  user_data = templatefile(var.app_config_filepath, {
    SECRET_MANAGER_NAME = var.secret_manager_name
  })
  key_name             = module.key.key_name
  iam_instance_profile = module.iam.iam_instance_profile_name
  max_size             = "8"
  min_size             = "2"
  desired_cap          = "2"
  subnet_ids           = module.vpc.app_subnets_ids
  tier_instance_sg     = module.sg.private_instances_sg
  lb_tg_arn            = module.app_tier_lb.target_group_arn
  depends_on           = [module.vpc, module.secret_manager, module.app_tier_lb]
}

########## Website Deploymnet ##########
########################################

# Create ACM for encrypting user data
module "acm" {
  source                     = "git@github.com:D-Mwanth/tf-custom-modules.git//acm?ref=main"
  domain                     = var.domain_name
  additional_acm_domain_name = var.additional_acm_domain_name
}

# Create Internet-facing (Web tier) loadbalancer deployment
module "web_tier_lb" {
  source          = "git@github.com:D-Mwanth/tf-custom-modules.git//lb?ref=main" #/web_lb"
  vpc_id          = module.vpc.vpc_id
  lb_name         = var.web_tier_lb
  certificate_arn = module.acm.acm_arn
  security_group  = module.sg.internet_facing_lb_sg
  subnets         = module.vpc.web_subnets_ids
  internal        = false

  depends_on = [module.acm]
}

# Create AWS WAF for filtering Web traffic at the application load balancer level
module "aws_wafv2" {
  source     = "git@github.com:D-Mwanth/tf-custom-modules.git//WAF?ref=main"
  waf_name   = var.waf_name
  alb_arn    = module.web_tier_lb.lb_arn
  depends_on = [module.web_tier_lb, module.web_tier_asg]
}

# Create DNS Name to point to the Application loadbalancer
module "route_53_dns_name" {
  source             = "git@github.com:D-Mwanth/tf-custom-modules.git//route53?ref=main"
  web_domain_name    = var.additional_domain_name
  public_lb_dns_name = module.web_tier_lb.lb_dns_name
  public_lb_zone_id  = module.web_tier_lb.lb_zone_id
  depends_on         = [module.web_tier_lb]
}

# Autoscaling group for Web Tier
module "web_tier_asg" {
  source        = "git@github.com:D-Mwanth/tf-custom-modules.git//asg?ref=main"
  tier_name     = "web-tier"
  instance_type = var.instance_type
  user_data = templatefile(var.web_config_filepath, {
    ELB_DNS_NAME = module.app_tier_lb.lb_dns_name
  })
  key_name             = module.key.key_name
  iam_instance_profile = module.iam.iam_instance_profile_name
  max_size             = "8"
  min_size             = "2"
  desired_cap          = "2"
  subnet_ids           = module.vpc.web_subnets_ids
  tier_instance_sg     = module.sg.public_instance_sg
  lb_tg_arn            = module.web_tier_lb.target_group_arn
  depends_on           = [module.vpc, module.web_tier_lb, module.app_tier_asg]
}