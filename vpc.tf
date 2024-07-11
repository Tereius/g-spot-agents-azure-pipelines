resource "google_compute_network" "vpc_network" {
  name                    = "spot-agent-network"
  description             = "The network the spot agents will join"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "spot-agent-subnetwork"
  description   = "The subnetwork the spot agents will join"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.vpc_network.name
  private_ip_google_access = true
}
