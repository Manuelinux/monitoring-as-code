
terraform {
  backend "s3" {
    profile = "prod"
    bucket  = "armory-terraform-states"
    key     = "managed_services/monitoring/terraform.tfstate"
    region  = "us-west-2"
  }
}

provider "pagerduty" {
  token = trimspace(file(pathexpand("~/.config/pager_duty_key")))
}

module "pager_duty" {
  source             = "../teams/"
  managers           = ["brian.newton@armory.io", "jason.mcintosh@armory.io"]
  members            = ["manuel.aguirre@armory.io", "jorge.hernandez@armory.io", "ramon.esparza@armory.io"]
  on_call_rotation   = ["manuel.aguirre@armory.io", "jorge.hernandez@armory.io", "ramon.esparza@armory.io", "jason.mcintosh@armory.io"]
  teamName           = "Managed Services Team"
  service_to_monitor = "DataDog Managed Customers"
}

## Setup monitors...
data "vault_generic_secret" "datadog_keys" {

  path = "secret/production/datadog/managed_services"
}
provider "datadog" {
  api_key = data.vault_generic_secret.datadog_keys.data["api_key"]
  app_key = data.vault_generic_secret.datadog_keys.data["app_key"]
}


module "base_rules_core_services" {
  source   = "../rules/spinnaker"
  services = ["clouddriver", "echo", "front50", "orca", "fiat", "gate", "igor", "kayenta", "rosco"]
}

