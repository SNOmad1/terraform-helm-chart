locals {
  required_values = {
    # Deployment endpoint for ingress
    deployment_endpoint = "${lower(var.deployment_endpoint)}"
    # <deployment_name> for backend.tf and also release name
    deployment_name     = "${lower(var.deployment_name)}"
    # <env_vars> for global environment variables takes map()
    env_vars            = "${trimspace(join("\n", data.template_file.env_vars.*.rendered))}"
  }
  # When all requred values all deffined then also will incloude users values
  template_all_values = "${merge(local.required_values, var.template_custom_vars)}"
  timeout             = "${var.timeout}"
  recreate_pods       = "${var.recreate_pods}"
}

# template_file.env_vars just converting to right values
data "template_file" "env_vars" {
  count    = "${length(keys(var.env_vars))}"
  template = "  $${key}: \"$${value}\""
  vars {
    key   = "${element(keys(var.env_vars), count.index)}"
    value = "${element(values(var.env_vars), count.index)}"
  }
}

# template_file.chart_values_template actual values.yaml file from charts
data "template_file" "chart_values_template" {
  count    = "${var.enabled == "true" ? 1 : 0 }"
  template = "${file("${var.deployment_path}/values.yaml")}"
  vars     = "${local.template_all_values}"
}

# This resource was disabled and moved to output please see the ticket
# https://github.com/fuchicorp/terraform-helm-chart/issues/21
# resource "local_file" "deployment_values" {
#   content  = "${trimspace(data.template_file.chart_values_template.0.rendered)}"
#   filename = "${path.module}/${var.deployment_name}-values.yaml"
# }

output "deployment_values" {
  value       = "${data.template_file.chart_values_template.*.rendered}"
  description = "This output is for storing values.yaml"
}

locals {
  trigger = "${var.trigger == "UUID" ? uuid() : var.trigger}"
}

# helm_release.helm_deployment is actual helm deployment
resource "helm_release" "helm_deployment" {
  count         = "${var.enabled == "true" ? 1 : 0}"
  name          = "${var.deployment_name}-${var.deployment_environment}"
  namespace     = "${var.deployment_environment}"
  chart         = "${var.deployment_path}"
  timeout       = "${local.timeout}"
  recreate_pods = "${local.recreate_pods}"
  version       = "${var.release_version}"
  values        = [
    "${trimspace(data.template_file.chart_values_template.rendered)}",
  ]
}