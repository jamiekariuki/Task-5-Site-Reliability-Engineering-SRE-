output "frontend_repository_url" {
  value = module.ecr-frontend.repository_url
}

output "backend_repository_url" {
  value = module.ecr-backend.repository_url
}


output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
}


