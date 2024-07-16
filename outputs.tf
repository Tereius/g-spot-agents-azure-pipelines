output "azure_webhook_url" {
  value       = "${google_cloud_run_v2_service.agent_autoscaler.uri}/${random_string.route_webhook.result}"
  description = "The url the Azure DevOps webhook should call"
}

output "azure_poll_url" {
  value       = "${google_cloud_run_v2_service.agent_autoscaler.uri}/${random_string.route_poll.result}"
  description = "The url the triggers a scaling operation"
}
