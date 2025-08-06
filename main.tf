locals {
  account_role_prefix  = "${var.cluster_name}-account"
  operator_role_prefix = "${var.cluster_name}-operator"
}
provider "kubernetes" {
  config_path = module.rosa_cluster_hcp.kubeconfig_path
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix              = var.cluster_name
  availability_zones_count = 3
}


############################
# Cluster
############################
module "hcp" {
  source = "terraform-redhat/rosa-hcp/rhcs"

  cluster_name             = var.cluster_name
  openshift_version        = var.openshift_version
  machine_cidr             = module.vpc.cidr_block
  aws_subnet_ids           = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  aws_availability_zones   = module.vpc.availability_zones
  replicas                 = length(module.vpc.availability_zones)
  create_admin_user        = true
  ec2_metadata_http_tokens = "required"
  // STS configuration
  create_account_roles  = true
  account_role_prefix   = local.account_role_prefix
  create_oidc           = true
  create_operator_roles = true
  operator_role_prefix  = local.operator_role_prefix
  
  depends_on = [module.vpc]
}

############################
# HTPASSWD IDP
############################
module "htpasswd_idp" {
  source = "./modules/idp"

  cluster_id         = module.hcp.cluster_id
  name               = "htpasswd-idp"
  idp_type           = "htpasswd"
  htpasswd_idp_users = [{ username = "test-user", password = random_password.password.result }]
}

resource "random_password" "password" {
  length  = 14
  special = true
  min_lower = 1
  min_numeric = 1
  min_special = 1
  min_upper = 1
}

