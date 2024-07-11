data "google_compute_default_service_account" "default_sa" {
}

data "google_project" "project" {
}

resource "google_project_iam_member" "cloudbuild" {
  project = data.google_compute_default_service_account.default_sa.project
  member   = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  for_each = toset(["roles/logging.logWriter", "roles/artifactregistry.repositories.downloadArtifacts"])
  role     = each.key
}

resource "google_project_iam_member" "compute_sa_bucket_access" {
  project = data.google_compute_default_service_account.default_sa.project
  #role    = "roles/storage.objectViewer"
  member   = "serviceAccount:${data.google_compute_default_service_account.default_sa.email}"
  for_each = toset(["roles/storage.objectViewer", "roles/logging.logWriter"])
  role     = each.key
}
