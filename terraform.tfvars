env                        = "dev"
project_name               = "3-tier-arch"
region                     = "us-east-1"
azs                        = ["us-east-1a", "us-east-1b"]
vpc_cidr_block             = "10.0.0.0/16"
public_subnets             = ["10.0.1.0/24", "10.0.2.0/24"]
app_subnets                = ["10.0.3.0/24", "10.0.4.0/24"]
db_subnets                 = ["10.0.5.0/24", "10.0.6.0/24"]
db_username                = "admin"
db_password                = "admin-123"
app_database               = "webappdb"
domain_name                = "bughunter.life"
additional_acm_domain_name = "*.bughunter.life"
additional_domain_name     = "3-tier.bughunter.life"
app_config_filepath        = "./server-boot/app-tier-userdata.tpl"
web_config_filepath        = "./server-boot/web-tier-userdata.tpl"
waf_name                   = "WebACL"
secret_manager_name        = "db-creds-005"
instance_type              = "t2.medium"
public_key_path            = "./key/client_key.pub"
web_tier_lb                = "web-tier-lb"
app_tier_lb                = "app-tier-lb"