terraform {
  required_version = ">= 1.9"
}

variable "flow_logs" {
  description = "Flow log instances to deploy, keyed by name"
  type        = any
  default     = {}
}

variable "vpc_ids" {
  description = "Map of VPC config-name to its ID, e.g. { for k, v in module.vpc : k => v.id }. A flow log picks one with vpc_key."
  type        = map(string)
  default     = {}
}

module "flow_log" {
  source   = "github.com/canada-ca-terraform-modules/terraform-aws-caf-flow_log.git?ref=v1.0.0"
  for_each = var.flow_logs

  userDefinedString = each.key
  env               = var.env
  vpc_ids           = var.vpc_ids
  flow_log          = each.value
  tags              = var.tags
}
