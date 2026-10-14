# Replace with the DNS name you control for this environment.
domain_name = "dev.example.com"

app_env = {
  OTEL_SERVICE_NAME = "ecommerce-backend"
  KASHIER_MODE      = "test"
  KASHIER_CURRENCY  = "EGP"
}

# Replace these Grafana Cloud values with those from your own stack and AWS integration.
grafana_stack_slug               = "your-grafana-stack-slug"
grafana_external_id              = "your-grafana-external-id"
grafana_cloud_provider_api_url   = "https://cloud-provider-api-prod-eu-west-4.grafana.net"
grafana_otlp_instance_id         = "your-grafana-otlp-instance-id"
# Replace with the OTLP endpoint and PrivateLink service name created for your Grafana Cloud stack.
grafana_otlp_endpoint            = "https://your-otlp-endpoint.example/otlp"
grafana_privatelink_service_name = "com.amazonaws.vpce.eu-central-1.vpce-svc-your-service-id"
