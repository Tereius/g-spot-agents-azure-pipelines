locals {
  agent_name_conditions           = [for s in google_compute_instance.spot_instance : format("resource.name == '%s'", s.id)]
  agent_name_conditions_condition = join(" || ", local.agent_name_conditions)
  agent_name_titles               = [for s in google_compute_instance.spot_instance : s.name]
  agent_name_titles_string        = join(", ", local.agent_name_titles)
}

data "google_compute_default_service_account" "default_sa" {
}

# resource "google_project_iam_member" "cloudbuild" {
#   project = data.google_compute_default_service_account.default_sa.project
#   member   = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
#   for_each = toset(["roles/logging.logWriter", "roles/artifactregistry.repositories.downloadArtifacts"])
#   role     = each.key
# }

// allow cloud run to pull image from container registry
resource "google_project_iam_member" "cloud_run_member" {
  project  = local.projectId
  member   = "serviceAccount:service-${data.google_project.current.number}@serverless-robot-prod.iam.gserviceaccount.com"
  for_each = toset(["roles/artifactregistry.reader"])
  role     = each.key
}

resource "google_service_account" "agent_autoscaler" {
  account_id   = "agent-autoscaler-serva"
  display_name = "agent-autoscaler"
}

#resource "google_project_iam_member" "compute_sa_bucket_access" {
#  project  = local.projectId
#  member   = "serviceAccount:${google_service_account.service_account.email}"
#  for_each = toset(["roles/artifactregistry.reader"])
#  role     = each.key
#}

resource "google_project_iam_custom_role" "start_stop_agent_spot" {
  role_id     = "StartStopInstances"
  title       = "Start/Stop instance(s)"
  permissions = ["compute.instances.get", "compute.instances.start", "compute.instances.stop"]
}

resource "google_project_iam_member" "agent_autoscaler_member" {
  project = local.projectId
  member  = "serviceAccount:${google_service_account.agent_autoscaler.email}"
  role    = google_project_iam_custom_role.start_stop_agent_spot.id
  condition {
    title      = "Instance oneof [${local.agent_name_titles_string}]"
    description = "Allow Start/Stop only for following instance(s): ${local.agent_name_titles_string}"
    expression = local.agent_name_conditions_condition
  }
}

// allow public access
// will not work if organization policy "Domain Restricted Sharing" is active in project
resource "google_cloud_run_service_iam_binding" "public_access" {
  location = google_cloud_run_v2_service.agent_autoscaler.location
  service  = google_cloud_run_v2_service.agent_autoscaler.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}
