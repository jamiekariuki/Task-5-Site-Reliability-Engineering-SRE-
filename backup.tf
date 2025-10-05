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
    config:
      global:
        resolve_timeout: 5m
      route:
        receiver: "email-alert"
        group_by: ['alertname']
        group_wait: 30s
        group_interval: 5m
        repeat_interval: 1h
      receivers:
        - name: "email-alert"
          email_configs:
            - to: "jamiekariuki18@gmail.com"
              from: "jamiekariuki18@gmail.com"
              smarthost: "smtp.gmail.com:587"
              auth_username: "jamiekariuki18@gmail.com"
              auth_identity: "jamiekariuki18@gmail.com"
              auth_password: a3puYiBya3JrIGVpaGwgeWV0bQo=
EOF
  ]

  depends_on = [module.eks]
}

