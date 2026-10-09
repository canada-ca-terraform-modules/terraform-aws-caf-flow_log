# Created only when no log_destination is given.
resource "aws_cloudwatch_log_group" "this" {
  for_each = local.log-destination-literal == null ? { enabled = true } : {}

  name              = local.log-group-name
  retention_in_days = try(var.flow_log.cloudwatch_log_group.retention_in_days, 731)
  kms_key_id        = try(var.flow_log.cloudwatch_log_group.kms_key_id, null)
  log_group_class   = try(var.flow_log.cloudwatch_log_group.log_group_class, null)
  skip_destroy      = try(var.flow_log.cloudwatch_log_group.skip_destroy, null)

  # Tags - Merging tags provided by ESLZ with tags provided by the user
  tags = merge(var.tags, try(var.flow_log.cloudwatch_log_group.tags, {}), local.module_tag, { Name = local.log-group-name })
}
