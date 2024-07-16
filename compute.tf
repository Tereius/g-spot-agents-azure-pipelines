resource "google_compute_instance" "spot_instance" {
  for_each        = toset(var.spot_agents)
  name            = each.value
  zone            = local.zone
  machine_type    = var.spot_machine_type
  tags            = ["http-egress", "ssh-ingress"]

  scheduling {
    preemptible                 = true
    automatic_restart           = false
    on_host_maintenance         = "TERMINATE"
    instance_termination_action = "STOP"
    provisioning_model          = "SPOT"
  }

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.spot_machine_image
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnetwork.name

    access_config {
      network_tier = "STANDARD"
    }
  }

  # show log: sudo journalctl -u google-startup-scripts.service
  # run again: sudo google_metadata_script_runner startup
  metadata_startup_script = <<EOT
#!/bin/bash
set -eo pipefail
if [ ! -f '/root/setup_done_${each.value}' ]; then
    echo "First time setup of agent '${each.value}' started"
    apt-get update && apt-get -y install docker.io docker-buildx
    if [ -f '/home/agent/svc.sh' ]; then
      echo "An other agent is already running - will be uninstalled"
      pushd /home/agent
      ./svc.sh stop || true
      ./svc.sh uninstall || true
      popd
    fi
    id -u agent &>/dev/null || useradd -d /home/agent -u 10000 agent
    usermod -aG docker agent
    newgrp docker
    wget -q -O /tmp/agent.tar.gz '${var.azure_agent_download_url}'
    rm -rf /home/agent &>/dev/null
    mkdir -p /home/agent
    chown -R agent:agent /home/agent
    pushd /home/agent
    sudo -u agent tar zxf /tmp/agent.tar.gz
    sudo -u agent ./config.sh --unattended --replace --url 'https://dev.azure.com/${var.azure_devops_organization}' --auth pat --token '${var.azure_pat}' --pool '${var.azure_devops_pool}' --agent '${each.value}' --acceptTeeEula
    ./bin/installdependencies.sh
    ./svc.sh install agent
    ./svc.sh start
    popd
    rm /tmp/agent.tar.gz
    touch '/root/setup_done_${each.value}'
    echo "First time setup finished"
else
    echo "Agent '${each.value}' already installed - skipping"
fi
docker system prune -af --volumes --filter "until=$((30*24))h"
EOT
}
