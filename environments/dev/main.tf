provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = "${var.project}-${var.environment}"
  cidr_block           = var.vpc_cidr_block
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.common_tags
}

module "vpc_routing" {
  source = "../../modules/vpc-routing"

  name               = "${var.project}-${var.environment}"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  tags = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  name              = "${var.project}-${var.environment}"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  target_port       = 80
  health_check_path = var.api_health_check_path

  tags = local.common_tags
}

module "asg_api" {
  source = "../../modules/asg-api"

  name                  = "${var.project}-${var.environment}"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn

  instance_type    = var.api_instance_type
  user_data        = file("${path.module}/templates/userdata.sh")
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity
  cpu_target_value = var.asg_cpu_target_value

  tags = local.common_tags

  # NAT Gateway経由の経路が確立してからEC2を起動する
  depends_on = [module.vpc_routing]
}
