/*
resource "google_pubsub_topic" "poll_agent_pool_jobs_topic" {
  name = "poll-agent-pool-jobs"

  labels = {
    foo = "bar"
  }

  message_retention_duration = "600s"
}

resource "google_pubsub_subscription" "poll_agent_pool_jobs_topic_sub" {
  name  = google_pubsub_topic.poll_agent_pool_jobs_topic.name + "-sub"
  topic = google_pubsub_topic.poll_agent_pool_jobs_topic.id

  ack_deadline_seconds = 20
  retain_acked_messages = false

  expiration_policy {
    ttl = "60s"
  }

  retry_policy {
    minimum_backoff = "1s"
    maximum_backoff = "5s"
  }

  labels = {
    foo = "bar"
  }
}
*/
