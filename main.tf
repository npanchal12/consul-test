module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.78.0"

  name                 = "${local.cluster_id}-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets      = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

data "aws_eks_cluster" "cluster" {
  count = local.install_eks_cluster ? 1 : 0
  name  = module.eks[0].cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  count = local.install_eks_cluster ? 1 : 0
  name  = module.eks[0].cluster_id
}

module "eks" {
  count                  = local.install_eks_cluster ? 1 : 0
  source                 = "terraform-aws-modules/eks/aws"
  version                = "17.24.0"
  kubeconfig_api_version = "client.authentication.k8s.io/v1beta1"

  cluster_name    = "${local.cluster_id}-eks"
  cluster_version = "1.27"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  


  manage_aws_auth = true
  rolearn = "arn:aws:iam::614349650737:role/aws-reserved/sso.amazonaws.com/ap-southeast-1/AWSReservedSSO_AdministratorAccess_f9b7ea4abaac0a4a"

  node_groups = {
    application = {
      name_prefix      = "hashicups"
      instance_types   = ["t3a.medium"]
      desired_capacity = 3
      max_capacity     = 3
      min_capacity     = 3
    }
  }
}

# The HVN created in HCP
resource "hcp_hvn" "main" {
  hvn_id         = local.hvn_id
  cloud_provider = "aws"
  region         = local.hvn_region
  cidr_block     = "172.25.32.0/20"
}

module "aws_hcp_consul" {
  source  = "hashicorp/hcp-consul/aws"
  version = "~> 0.8.9"

  hvn                = hcp_hvn.main
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  route_table_ids    = module.vpc.private_route_table_ids
  security_group_ids = local.install_eks_cluster ? [module.eks[0].cluster_primary_security_group_id] : [""]
}

resource "hcp_consul_cluster" "main" {
  cluster_id      = local.cluster_id
  hvn_id          = hcp_hvn.main.hvn_id
  public_endpoint = true
  tier            = "development"
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = hcp_consul_cluster.main.id
}

module "eks_consul_client" {
  source  = "hashicorp/hcp-consul/aws//modules/hcp-eks-client"
  version = "~> 0.8.9"

  boostrap_acl_token    = hcp_consul_cluster_root_token.token.secret_id
  cluster_id            = hcp_consul_cluster.main.cluster_id
  consul_ca_file        = base64decode(hcp_consul_cluster.main.consul_ca_file)
  consul_hosts          = jsondecode(base64decode(hcp_consul_cluster.main.consul_config_file))["retry_join"]
  consul_version        = hcp_consul_cluster.main.consul_version
  datacenter            = hcp_consul_cluster.main.datacenter
  gossip_encryption_key = jsondecode(base64decode(hcp_consul_cluster.main.consul_config_file))["encrypt"]
  k8s_api_endpoint      = local.install_eks_cluster ? module.eks[0].cluster_endpoint : ""

  # The EKS node group will fail to create if the clients are
  # created at the same time. This forces the client to wait until
  # the node group is successfully created.
  depends_on = [module.eks]
}

module "demo_app" {
  count   = local.install_demo_app ? 1 : 0
  source  = "hashicorp/hcp-consul/aws//modules/k8s-demo-app"
  version = "~> 0.8.9"

  depends_on = [module.eks_consul_client]
}
