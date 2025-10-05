provider "aws" {
  region              = var.region
  allowed_account_ids = [var.aws_account_id]
}

# Get cluster info
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

# Get authentication token
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

# Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Helm provider
provider "helm" {
  kubernetes ={
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
