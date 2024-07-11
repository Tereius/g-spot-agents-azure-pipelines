/*
resource "google_cloudfunctions2_function" "poll_agent_pool_jobs" {
  name        = "poll-agent-pool-jobs"
  location    = provider::google::region_from_id(google_compute_subnetwork.subnetwork.id)
  description = "Regularly pools for new ci jobs assigned to a specifi azure pipelines agent pool"

  build_config {
    runtime     = "python312"
    entry_point = "poll_agent_jobs"

    source {

      storage_source {

        bucket = google_storage_bucket.cloud_function_code.name
        object = google_storage_bucket_object.poll_function.name
      }
    }
  }

  depends_on = [google_project_iam_member.compute_sa_bucket_access]

  service_config {
    max_instance_count               = 1
    min_instance_count               = 0
    available_memory                 = "128Mi"
    timeout_seconds                  = 60
    max_instance_request_concurrency = 1
    available_cpu                    = "0.25"
    ingress_settings                 = "ALLOW_ALL"
    all_traffic_on_latest_revision   = true
  }
}*/
