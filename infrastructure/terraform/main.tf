//vpc 
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  intra_subnets   = ["10.0.104.0/24", "10.0.105.0/24", "10.0.106.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  enable_dns_hostnames= true

  tags ={
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.33"

  # EKS Addons
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  endpoint_public_access  = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    example = {
      instance_types = ["t3.medium"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size = 1
      max_size = 3
      desired_size = 2

      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  shutdownGracePeriod: 30s
          EOT
        }
      ]
    }
  }
 
}

//frontend repository
module "ecr-frontend" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = "frontend-${var.ENV_PREFIX}-repository"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = var.ENV_PREFIX
  }
}

//backend repository
module "ecr-backend" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = "backend-${var.ENV_PREFIX}-repository"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = var.ENV_PREFIX
  }
}

# Built-in AWS managed policy for ECR pull
data "aws_iam_policy" "ecr_readonly" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Attach ECR read permissions to EKS node group role
resource "aws_iam_role_policy_attachment" "eks_nodes_ecr" {
  role       = module.eks.eks_managed_node_groups["example"].iam_role_name
  policy_arn = data.aws_iam_policy.ecr_readonly.arn
}

// prometheus testing
###############################
# 1️⃣ Install kube-prometheus-stack
###############################
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "65.3.0"
  namespace        = "monitoring"
  create_namespace = true

  values = [
    <<EOF
grafana:
  adminPassword: "mypassword"
  service:
    type: LoadBalancer
  ingress:
    enabled: false

prometheus:
  service:
    type: LoadBalancer

alertmanager:
  enabled: true
  service:
    type: LoadBalancer
  alertmanagerSpec:
    replicas: 1
EOF
  ]

  depends_on = [module.eks]
}

###############################
# 2️⃣ Create Kubernetes Secret for Gmail
###############################
resource "kubernetes_secret" "mail_pass" {
  metadata {
    name      = "mail-pass"
    namespace = "monitoring"
  }

  type = "Opaque"

  data = {
    "gmail-pass" = "a3puYiBya3JrIGVpaGwgeWV0bQo="
  }
}

###############################
# 3️⃣ Create AlertmanagerConfig with proper routing
###############################
resource "kubernetes_manifest" "alertmanager_config" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "AlertmanagerConfig"
    metadata = {
      name      = "email-alert-config"
      namespace = "monitoring"
      labels = {
        release = "monitoring"
      }
    }
    spec = {
      route = {
        receiver       = "send-email"
        groupBy        = ["alertname"]
        groupWait      = "30s"
        groupInterval  = "5m"
        repeatInterval = "1h"
        routes = [
          {
            matchers = [
              { name = "alertname", value = "TestEmail" }
            ]
            receiver = "send-email"
          }
        ]
      }
      receivers = [
        {
          name = "send-email"
          emailConfigs = [
            {
              to           = "jamiekariuki18@gmail.com"
              from         = "jamiekariuki18@gmail.com"
              sendResolved = true
              smarthost    = "smtp.gmail.com:587"
              authUsername = "jamiekariuki18@gmail.com"
              authIdentity = "jamiekariuki18@gmail.com"
              authPassword = {
                name = kubernetes_secret.mail_pass.metadata[0].name
                key  = "gmail-pass"
              }
            }
          ]
        },
        { name = "null" }
      ]
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubernetes_secret.mail_pass
  ]
}

























