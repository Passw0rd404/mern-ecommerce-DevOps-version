locals {
  atlas_region = upper(replace(var.region, "-", "_"))

  private_endpoints = coalesce(mongodbatlas_advanced_cluster.this.connection_strings.private_endpoint, [])
  private_srv = [
    for pe in local.private_endpoints : pe.srv_connection_string
    if contains([for e in pe.endpoints : e.endpoint_id], var.vpc_endpoint_id)
  ]
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "mongodbatlas_project" "this" {
  name   = var.project_name
  org_id = var.atlas_org_id
}

resource "mongodbatlas_private_endpoint_regional_mode" "this" {
  project_id = mongodbatlas_project.this.id
  enabled    = true
}

resource "mongodbatlas_privatelink_endpoint" "this" {
  project_id    = mongodbatlas_project.this.id
  provider_name = "AWS"
  region        = var.region

  depends_on = [mongodbatlas_private_endpoint_regional_mode.this]
}

resource "mongodbatlas_privatelink_endpoint_service" "this" {
  project_id          = mongodbatlas_project.this.id
  private_link_id     = mongodbatlas_privatelink_endpoint.this.private_link_id
  endpoint_service_id = var.vpc_endpoint_id
  provider_name       = "AWS"
}

resource "mongodbatlas_advanced_cluster" "this" {
  project_id   = mongodbatlas_project.this.id
  name         = var.cluster_name
  cluster_type = "REPLICASET"

  mongo_db_major_version         = var.mongo_db_major_version
  backup_enabled                 = true
  termination_protection_enabled = var.termination_protection
  use_effective_fields           = true

  replication_specs = [{
    region_configs = [{
      provider_name = "AWS"
      region_name   = local.atlas_region
      priority      = 7

      electable_specs = {
        instance_size = var.instance_size
        node_count    = 3
      }

      auto_scaling = {
        compute_enabled            = true
        compute_scale_down_enabled = true
        compute_min_instance_size  = var.instance_size
        compute_max_instance_size  = var.max_instance_size
        disk_gb_enabled            = true
      }
    }]
  }]

  advanced_configuration = {
    minimum_enabled_tls_protocol = "TLS1_2"
    javascript_enabled           = false
  }

  # The private endpoint must exist first so its connection string is in the cluster's attributes
  depends_on = [mongodbatlas_privatelink_endpoint_service.this]
}

resource "mongodbatlas_database_user" "this" {
  project_id         = mongodbatlas_project.this.id
  username           = var.db_username
  password           = random_password.db.result
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = var.database_name
  }

  scopes {
    name = mongodbatlas_advanced_cluster.this.name
    type = "CLUSTER"
  }
}
