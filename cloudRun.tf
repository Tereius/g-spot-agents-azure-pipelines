locals {
  auth_user  = "ci_user"
  basic_auth = base64encode("${local.auth_user}:${random_password.auth_password.result}")
}

resource "random_password" "auth_password" {
  length  = 16
  special = true
}

resource "random_string" "route_poll" {
  length  = 16
  special = false
  numeric = false
  upper   = false
  lower   = true
}

resource "random_string" "route_webhook" {
  length  = 16
  special = false
  numeric = false
  upper   = false
  lower   = true
}

resource "google_cloud_run_v2_service" "agent_autoscaler" {
  location   = local.region
  name       = "cloudrun-service"
  ingress    = "INGRESS_TRAFFIC_ALL"
  depends_on = [google_artifact_registry_repository.ghcr, google_project_service.cloud_run_api]

  template {
    service_account                  = google_service_account.agent_autoscaler.email
    max_instance_request_concurrency = 1
    timeout                          = "120s"
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
    containers {
      image = "${local.region}-docker.pkg.dev/${local.projectId}/${google_artifact_registry_repository.ghcr.name}/tereius/agent-autoscaler:latest"
      env {
        name  = "ROUTE_POLL"
        value = "/${random_string.route_poll.result}"
      }
      env {
        name  = "ROUTE_WEBHOOK"
        value = "/${random_string.route_webhook.result}"
      }
      env {
        name  = "AGENTS"
        value = join(",", var.spot_agents)
      }
      env {
        name  = "AZURE_PAT"
        value = var.azure_pat
      }
      env {
        name  = "AZURE_ORGANIZATION"
        value = var.azure_devops_organization
      }
      env {
        name  = "AZURE_POOL_ID"
        value = var.azure_devops_pool_id
      }
      env {
        name  = "PROJECT_ID"
        value = local.projectId
      }
      env {
        name  = "ZONE"
        value = local.zone
      }
      env {
        name  = "AUTH_USER"
        value = local.auth_user
      }
      env {
        name  = "AUTH_PASSWORD"
        value = random_password.auth_password.result
      }
      dynamic "env" {
        for_each = var.enable_debug ? [0] : []
        content {
          name  = "DEBUG"
          value = 1
        }
      }
      resources {
        startup_cpu_boost = false
        cpu_idle          = true
        limits = {
          cpu    = "0.08"
          memory = "128Mi"
        }
      }
    }
  }
}
