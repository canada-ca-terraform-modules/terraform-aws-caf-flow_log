locals {
  # Where the flow log is attached: exactly one of these must be set.
  targets = {
    vpc_id                        = try(var.flow_log.vpc_id, var.vpc_ids[var.flow_log.vpc_key], null)
    subnet_id                     = try(var.flow_log.subnet_id, null)
    eni_id                        = try(var.flow_log.eni_id, null)
    regional_nat_gateway_id       = try(var.flow_log.regional_nat_gateway_id, null)
    transit_gateway_id            = try(var.flow_log.transit_gateway_id, null)
    transit_gateway_attachment_id = try(var.flow_log.transit_gateway_attachment_id, null)
  }
  # The provider takes no traffic_type for transit gateway flow logs.
  on-transit-gateway = local.targets.transit_gateway_id != null || local.targets.transit_gateway_attachment_id != null

  log-destination-literal = try(var.flow_log.log_destination, null)
  destination-type = try(var.flow_log.log_destination_type, (
    local.log-destination-literal == null ? "cloud-watch-logs"
    : startswith(local.log-destination-literal, "arn:aws:s3:::") ? "s3"
    : can(regex(":firehose:", local.log-destination-literal)) ? "kinesis-data-firehose"
    : "cloud-watch-logs"
  ))
  log-destination  = try(aws_cloudwatch_log_group.this["enabled"].arn, local.log-destination-literal)
  iam-role-literal = try(var.flow_log.iam_role_arn, null)
  # Keys only: iterating the role resource itself would drag in its deprecated managed_policy_arns.
  role-instances = local.destination-type == "cloud-watch-logs" && local.iam-role-literal == null ? { enabled = true } : {}
}

resource "aws_flow_log" "this" {
  vpc_id                        = local.targets.vpc_id
  subnet_id                     = local.targets.subnet_id
  eni_id                        = local.targets.eni_id
  regional_nat_gateway_id       = local.targets.regional_nat_gateway_id
  transit_gateway_id            = local.targets.transit_gateway_id
  transit_gateway_attachment_id = local.targets.transit_gateway_attachment_id

  traffic_type               = try(var.flow_log.traffic_type, local.on-transit-gateway ? null : "ALL")
  log_destination_type       = local.destination-type
  log_destination            = local.log-destination
  iam_role_arn               = local.iam-role-literal != null ? local.iam-role-literal : try(aws_iam_role.this["enabled"].arn, null)
  log_format                 = try(var.flow_log.log_format, null)
  max_aggregation_interval   = try(var.flow_log.max_aggregation_interval, null)
  deliver_cross_account_role = try(var.flow_log.deliver_cross_account_role, null)

  dynamic "destination_options" {
    for_each = try(var.flow_log.destination_options, null) != null ? { enabled = var.flow_log.destination_options } : {}
    content {
      file_format                = try(destination_options.value.file_format, null)
      hive_compatible_partitions = try(destination_options.value.hive_compatible_partitions, null)
      per_hour_partition         = try(destination_options.value.per_hour_partition, null)
    }
  }

  dynamic "tag_field_specification" {
    for_each = try(var.flow_log.tag_field_specification, {})
    content {
      resource_type = tag_field_specification.value.resource_type
      tag_keys      = tag_field_specification.value.tag_keys
    }
  }

  # Tags - Merging tags provided by ESLZ with tags provided by the user. Name is last so the naming standard wins.
  tags = merge(var.tags, try(var.flow_log.tags, {}), local.module_tag, { Name = local.flow-log-name })

  # Without the policy the first deliveries can fail.
  depends_on = [aws_iam_role_policy.this]

  lifecycle {
    precondition {
      condition     = try(var.flow_log.vpc_key, null) == null || contains(keys(var.vpc_ids), var.flow_log.vpc_key)
      error_message = "flow_log.vpc_key \"${try(var.flow_log.vpc_key, "")}\" is not a key of vpc_ids (${join(", ", keys(var.vpc_ids))})."
    }
    precondition {
      condition     = length([for v in values(local.targets) : v if v != null]) == 1
      error_message = "Set exactly one of flow_log.vpc_key, vpc_id, subnet_id, eni_id, regional_nat_gateway_id, transit_gateway_id or transit_gateway_attachment_id."
    }
    precondition {
      condition     = local.log-destination-literal != null || local.destination-type == "cloud-watch-logs"
      error_message = "flow_log.log_destination is required unless log_destination_type is cloud-watch-logs (the module then creates the log group)."
    }
  }
}
