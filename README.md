# g-spot-agents-azure-pipelines

### no pun intended

# Proof of concept - currently not usable

The DevOps build agents [hosted by Microsoft](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml#software) are very limited in cpu, memory and storage: It is not possible to cross compile a Qt6 application for arm64 because the agent will run out of ephemeral storage. This terraform module provisions one/multiple Google Cloud Spot VMs of your choice that will automatically register as self hosted agents in your agent pool in your Azure organization. The Spot VMs will be monitored by a Cloud Run instance that automatically starts the VMs as soon as CI jobs get assigned to the agent pool and will stop them if there are no jobs left. The functionality is based on the undocumented Azure Pipelines API call:
`GET https://dev.azure.com/<organization>/_apis/distributedtask/pools/<agent_pool_id>/jobrequests?api-version=6.0`


## Warning

I am not responsible if this Terraform module results in high costs on your billing account. Keep an eye on your billing account.
