resource "google_artifact_registry_repository" "my-repo" {
  location      = provider::google::region_from_id(google_compute_subnetwork.subnetwork.id)
  repository_id = "spot-agent-ghcr"
  description   = "Git hub container registry"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  cleanup_policies {
    id     = "keep-one-version"
    action = "KEEP"
    most_recent_versions {
      keep_count = 1
    }
  }
}
