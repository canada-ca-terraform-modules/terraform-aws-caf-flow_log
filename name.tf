## Names follow Documentation/Standards/AWS-Naming-and-Tagging-Suffixes.md: <env>-<userDefinedString>-<suffix>.
## Limits come from references/naming-rules.md: IAM role <=64, CloudWatch log group <=512
## (letters, digits and . - _ / #), and <=256 for the Name tag of the flow log, which has no name argument.
## The shared base is capped at 50 so every suffix fits the IAM role limit.
locals {
  name-regex     = "/[^0-9a-z-]/"
  env-compliant  = replace(lower(var.env), local.name-regex, "")
  name-compliant = replace(lower(var.userDefinedString), local.name-regex, "")

  # Truncate, then trim: the cut (or an empty env) can leave a leading/trailing hyphen.
  base-name-auto = trim(substr("${local.env-compliant}-${local.name-compliant}", 0, 50), "-")

  flow-log-name-custom = trim(substr(replace(try(lower(var.flow_log.name), ""), local.name-regex, ""), 0, 255), "-")
  flow-log-name        = local.flow-log-name-custom != "" ? local.flow-log-name-custom : "${local.base-name-auto}-flowlog"
  base-name            = local.flow-log-name-custom != "" ? trim(substr(local.flow-log-name-custom, 0, 50), "-") : local.base-name-auto

  role-name-custom = trim(substr(replace(try(lower(var.flow_log.iam_role.name), ""), local.name-regex, ""), 0, 64), "-")
  role-name        = local.role-name-custom != "" ? local.role-name-custom : "${local.base-name}-role"

  log-group-regex       = "/[^0-9a-z._#/-]/"
  log-group-name-custom = trim(substr(replace(try(lower(var.flow_log.cloudwatch_log_group.name), ""), local.log-group-regex, ""), 0, 512), "-")
  log-group-name        = local.log-group-name-custom != "" ? local.log-group-name-custom : "/vpc/flow-logs/${local.base-name}-log"
}
