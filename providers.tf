terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.43"
    }

    hcp = {
      source  = "hashicorp/hcp"
      version = ">= 0.18.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.4.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.3.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }

}

provider "aws" {
  region = local.vpc_region
}

provider "hcp" {
  client_id     = "Sb8YfG0zCUdQBxW6jws9AZ5z6meouQkO"
  client_secret = "2WClq2535hMfzq6mAFx-OLZvhzEeCRgNEYQaNcuUI8Ui2-fY2WyleqpBJtNaexlE"
}

provider "helm" {
  kubernetes {
    host                   = local.install_eks_cluster ? data.aws_eks_cluster.cluster[0].endpoint : ""
    cluster_ca_certificate = local.install_eks_cluster ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : ""
    token                  = local.install_eks_cluster ? data.aws_eks_cluster_auth.cluster[0].token : ""
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_id]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = local.install_eks_cluster ? data.aws_eks_cluster.cluster[0].endpoint : ""
  cluster_ca_certificate = local.install_eks_cluster ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : ""
  token                  = local.install_eks_cluster ? data.aws_eks_cluster_auth.cluster[0].token : ""
}

provider "kubectl" {
  host                   = local.install_eks_cluster ? data.aws_eks_cluster.cluster[0].endpoint : ""
  cluster_ca_certificate = local.install_eks_cluster ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : ""
  token                  = local.install_eks_cluster ? data.aws_eks_cluster_auth.cluster[0].token : ""
  load_config_file       = false
}
