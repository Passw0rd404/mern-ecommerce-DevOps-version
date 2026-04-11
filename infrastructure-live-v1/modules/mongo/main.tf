resource "mongodbatlas_project" "this" {
  name   = var.project_name
  org_id = var.atlas_org_id
}

resource "mongodbatlas_cluster" "this" {
  project_id = mongodbatlas_project.this.id
  name       = var.cluster_name

  # Free tier (M0)
  provider_name               = "TENANT"
  backing_provider_name       = var.cloud_provider
  provider_region_name        = var.region
  provider_instance_size_name = "M0"

  # M0 does not support these — must be false
  auto_scaling_disk_gb_enabled = false
}

resource "mongodbatlas_database_user" "this" {
  project_id         = mongodbatlas_project.this.id
  username           = var.db_username
  password           = var.db_password
  auth_database_name = "admin"

  roles {
    role_name     = "readWriteAnyDatabase"
    database_name = "admin"
  }
}

resource "mongodbatlas_project_ip_access_list" "this" {
  project_id = mongodbatlas_project.this.id
  cidr_block = var.allowed_cidr
  comment    = "allowed CIDR for DB access"
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