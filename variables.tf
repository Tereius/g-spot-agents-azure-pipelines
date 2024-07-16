variable "spot_agents" {
  type        = list(string)
  description = "Provide a list of agent names. For each name a new spot instance will be created and supervised - the names have to be unique"
  default     = ["default"]
}

variable "spot_machine_type" {
  type        = string
  description = "The machine type that each spot agent will use"
  default     = "e2-micro"
}

variable "spot_machine_image" {
  type        = string
  description = "The machine Linux image to run (gcloud compute images list --filter ubuntu-os)"
  default     = "ubuntu-os-cloud/ubuntu-minimal-2004-lts"
}

variable "gcp_organization" {
  type        = string
  description = "(optionally) set the parent organization id of the project (this will add a organization key to enable public access)"
  default     = ""
}

variable "enable_ssh" {
  type        = bool
  description = "Enable SSH access"
  default     = false
}

variable "enable_debug" {
  type        = bool
  description = "Enable debug messages in agent-autoscaler (WARNING: secrets will be leaked in log files)"
  default     = false
}

variable "azure_pat" {
  type        = string
  sensitive   = true
  description = "A Personal Access Token with the following scopes: \"Agent Pools: Read & manage\" (you may want to remove the \"manage\" permission after the spot agents were registered)"
}

variable "azure_devops_organization" {
  type        = string
  description = "The name of the Azure DevOps organization"
}

variable "azure_devops_pool" {
  type        = string
  description = "The name of the agent pool where the spot agents will join"
}

variable "azure_devops_pool_id" {
  type        = number
  description = "The id of the agent pool where the spot agents will join"
}

variable "azure_agent_download_url" {
  type = string
  description = "The download link"
  default = "https://vstsagentpackage.azureedge.net/agent/3.241.0/vsts-agent-linux-x64-3.241.0.tar.gz"
}
