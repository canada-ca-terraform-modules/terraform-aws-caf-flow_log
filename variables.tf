variable "tags" {
  description = "Tags applied to all resources (merged with flow_log.tags)"
  type        = map(string)
  default     = {}
}

variable "env" {
  description = "(Required) env value used in name generation"
  type        = string
}

variable "userDefinedString" {
  description = "(Required) UserDefinedString part of the name of the flow log"
  type        = string

  validation {
    condition     = can(regex("[0-9A-Za-z]", var.userDefinedString))
    error_message = "userDefinedString must contain at least one letter or digit."
  }
}

variable "vpc_ids" {
  description = "Optional map of VPC key to its ID. Resolves flow_log.vpc_key. e.g. { for k, v in module.vpc : k => v.id }"
  type        = map(string)
  default     = {}
}

variable "flow_log" {
  description = "(Required) Object describing the flow log (see TFVars Parameters in the README). Optional `name` key overrides the auto-derived name."
  type        = any
  default     = {}
}
