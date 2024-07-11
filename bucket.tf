locals {
  project_id  = provider::google::project_from_id(google_compute_subnetwork.subnetwork.id)
  bucket_name = "${local.project_id}-poll-function-code"
}

resource "google_storage_bucket" "cloud_function_code" {
  name                        = local.bucket_name
  location                    = google_compute_subnetwork.subnetwork.region
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

data "archive_file" "code_dot_zip" {
  type        = "zip"
  output_path = "${path.cwd}/pollAgentJobsFunc.zip"
  source_dir  = "${path.module}/pollAgentJobsFunc"
}

resource "google_storage_bucket_object" "poll_function" {
  name       = "pollAgentJobsFunc.zip"
  bucket     = google_storage_bucket.cloud_function_code.name
  source     = data.archive_file.code_dot_zip.output_path
  depends_on = [data.archive_file.code_dot_zip]
}
