resource "google_cloud_scheduler_job" "poll" {
  name             = "poll_agents"
  description      = "test http job"
  schedule         = "*/5 * * * *"
  time_zone        = "America/New_York"
  attempt_deadline = "120s"

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_v2_service.agent_autoscaler.uri}/${random_string.route_poll.result}"
    headers = {
        "Authorization": "Basic ${local.basic_auth}"
    }
  }
}