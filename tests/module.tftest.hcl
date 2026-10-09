mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  # The provider validates ARNs, which the default mock strings are not.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:ca-central-1:111111111111:log-group:/vpc/flow-logs/mock"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111111111111:role/mock"
    }
  }
}

variables {
  env               = "Dev"
  userDefinedString = "myapp"
  tags              = { environment = "test" }
  vpc_ids           = { main = "vpc-0123456789abcdef0" }
  flow_log = {
    vpc_key = "main"
  }
}

# ---------------------------------------------------------------------------
# naming_convention
# Names are <env>-<userDefinedString>-<suffix>, lowercased and sanitized:
# flow log Name tag (<=256), IAM role (<=64), log group (<=512).
# ---------------------------------------------------------------------------
run "naming_convention" {
  command = plan

  assert {
    condition     = aws_flow_log.this.tags["Name"] == "dev-myapp-flowlog"
    error_message = "Flow log Name tag must be <env>-<userDefinedString>-flowlog"
  }
  assert {
    condition     = aws_iam_role.this["enabled"].name == "dev-myapp-role"
    error_message = "Role name must be <env>-<userDefinedString>-role"
  }
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].name == "/vpc/flow-logs/dev-myapp-log"
    error_message = "Log group name must be /vpc/flow-logs/<env>-<userDefinedString>-log"
  }
}

# ---------------------------------------------------------------------------
# naming_convention_minimum_length
# ---------------------------------------------------------------------------
run "naming_convention_minimum_length" {
  command = plan

  variables {
    env               = "d"
    userDefinedString = "a"
  }

  assert {
    condition     = aws_iam_role.this["enabled"].name == "d-a-role"
    error_message = "A one-character env and userDefinedString must still give a valid role name"
  }
}

# ---------------------------------------------------------------------------
# naming_convention_truncation_edge_case
# A long userDefinedString and a leading-hyphen env must stay within every limit.
# ---------------------------------------------------------------------------
run "naming_convention_truncation_edge_case" {
  command = plan

  variables {
    env               = "-prod"
    userDefinedString = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }

  assert {
    condition     = length(aws_iam_role.this["enabled"].name) <= 64
    error_message = "Role name must not exceed 64 characters even after truncation"
  }
  assert {
    condition     = !startswith(aws_iam_role.this["enabled"].name, "-")
    error_message = "The leading hyphen of env must not leak into the role name"
  }
  assert {
    condition     = length(aws_cloudwatch_log_group.this["enabled"].name) <= 512 && length(aws_flow_log.this.tags["Name"]) <= 256
    error_message = "Log group and Name tag must stay within their limits"
  }
}

# ---------------------------------------------------------------------------
# naming_convention_truncation_on_separator
# The 50-character cut lands on a hyphen here; it must be trimmed, not kept.
# ---------------------------------------------------------------------------
run "naming_convention_truncation_on_separator" {
  command = plan

  variables {
    userDefinedString = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbb"
  }

  assert {
    condition     = aws_iam_role.this["enabled"].name == "dev-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-role"
    error_message = "A hyphen left at the truncation point must be trimmed before the suffix is added"
  }
}

# ---------------------------------------------------------------------------
# naming_custom_name_override
# flow_log.name overrides the auto-derived name, sanitized the same way; the
# role and log group derive from it, and each can be overridden on its own.
# ---------------------------------------------------------------------------
run "naming_custom_name_override" {
  command = plan

  variables {
    flow_log = {
      vpc_key = "main"
      name    = "My-Custom-Name!"
    }
  }

  assert {
    condition     = aws_flow_log.this.tags["Name"] == "my-custom-name"
    error_message = "flow_log.name must override the auto-derived name, sanitized against the allowed charset"
  }
  assert {
    condition     = aws_iam_role.this["enabled"].name == "my-custom-name-role" && aws_cloudwatch_log_group.this["enabled"].name == "/vpc/flow-logs/my-custom-name-log"
    error_message = "Role and log group names must derive from the custom name"
  }
}

run "naming_custom_role_and_log_group_override" {
  command = plan

  variables {
    flow_log = {
      vpc_key              = "main"
      iam_role             = { name = "Custom-Role_1" }
      cloudwatch_log_group = { name = "/Custom/Log.Group_1" }
    }
  }

  assert {
    condition     = aws_iam_role.this["enabled"].name == "custom-role1"
    error_message = "iam_role.name must override the role name, sanitized against the allowed charset"
  }
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].name == "/custom/log.group_1"
    error_message = "cloudwatch_log_group.name must override the log group name, keeping / . _"
  }
}

# ---------------------------------------------------------------------------
# default_values
# A vpc_key alone gives a CloudWatch flow log of ALL traffic with a 731-day log group.
# ---------------------------------------------------------------------------
# Applied against the mock provider: the created log group and role ARNs are only known after apply.
run "default_values" {
  command = apply

  assert {
    condition     = aws_flow_log.this.vpc_id == "vpc-0123456789abcdef0"
    error_message = "vpc_key must resolve through vpc_ids"
  }
  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL" && aws_flow_log.this.log_destination_type == "cloud-watch-logs"
    error_message = "traffic_type must default to ALL and the destination to CloudWatch Logs"
  }
  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].retention_in_days == 731
    error_message = "The log group must default to two-year (731 day) retention"
  }
  assert {
    condition     = aws_flow_log.this.log_destination == "arn:aws:logs:ca-central-1:111111111111:log-group:/vpc/flow-logs/mock" && aws_flow_log.this.iam_role_arn == "arn:aws:iam::111111111111:role/mock"
    error_message = "The flow log must use the created log group and role"
  }
}

# ---------------------------------------------------------------------------
# tags_are_merged_with_module_tag
# ---------------------------------------------------------------------------
run "tags_are_merged_with_module_tag" {
  command = plan

  variables {
    flow_log = {
      vpc_key = "main"
      tags    = { owner = "team-x" }
    }
  }

  assert {
    condition     = aws_flow_log.this.tags["environment"] == "test" && aws_flow_log.this.tags["owner"] == "team-x"
    error_message = "Caller-supplied tags must be preserved"
  }
  assert {
    condition     = contains(keys(aws_flow_log.this.tags), "module") && contains(keys(aws_cloudwatch_log_group.this["enabled"].tags), "module") && contains(keys(aws_iam_role.this["enabled"].tags), "module")
    error_message = "module tag must be merged into the tags of every resource"
  }
}

# ---------------------------------------------------------------------------
# cloudwatch_log_group
# ---------------------------------------------------------------------------
run "cloudwatch_log_group_settings" {
  command = plan

  variables {
    flow_log = {
      vpc_key              = "main"
      cloudwatch_log_group = { retention_in_days = 90, skip_destroy = true }
    }
  }

  assert {
    condition     = aws_cloudwatch_log_group.this["enabled"].retention_in_days == 90 && aws_cloudwatch_log_group.this["enabled"].skip_destroy == true
    error_message = "cloudwatch_log_group settings must reach the log group"
  }
}

# ---------------------------------------------------------------------------
# iam_role
# ---------------------------------------------------------------------------
run "iam_role_policy_covers_the_log_group" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.this) == 1 && length(aws_iam_role.this) == 1
    error_message = "One role and one policy must be created for CloudWatch delivery"
  }
  assert {
    condition     = strcontains(aws_iam_role.this["enabled"].assume_role_policy, "vpc-flow-logs.amazonaws.com") && strcontains(aws_iam_role.this["enabled"].assume_role_policy, "aws:SourceAccount")
    error_message = "The role must trust the flow logs service, limited to this account"
  }
}

run "iam_role_settings" {
  command = plan

  variables {
    flow_log = {
      vpc_key  = "main"
      iam_role = { path = "/svc/", description = "delivers flow logs" }
    }
  }

  assert {
    condition     = aws_iam_role.this["enabled"].path == "/svc/" && aws_iam_role.this["enabled"].description == "delivers flow logs"
    error_message = "iam_role settings must reach the role"
  }
}

run "given_iam_role_arn_creates_no_role" {
  command = plan

  variables {
    flow_log = {
      vpc_key      = "main"
      iam_role_arn = "arn:aws:iam::111111111111:role/existing"
    }
  }

  assert {
    condition     = length(aws_iam_role.this) == 0 && length(aws_iam_role_policy.this) == 0 && aws_flow_log.this.iam_role_arn == "arn:aws:iam::111111111111:role/existing"
    error_message = "A given iam_role_arn must be used and no role created"
  }
}

# ---------------------------------------------------------------------------
# s3_destination
# An S3 ARN is used as is: no log group, no role, no IAM policy.
# ---------------------------------------------------------------------------
run "s3_destination" {
  command = plan

  variables {
    flow_log = {
      vpc_key         = "main"
      log_destination = "arn:aws:s3:::central-log-archive/flow-logs/"
      traffic_type    = "REJECT"
      destination_options = {
        file_format                = "parquet"
        hive_compatible_partitions = true
        per_hour_partition         = true
      }
    }
  }

  assert {
    condition     = aws_flow_log.this.log_destination_type == "s3" && aws_flow_log.this.log_destination == "arn:aws:s3:::central-log-archive/flow-logs/" && aws_flow_log.this.traffic_type == "REJECT"
    error_message = "An S3 destination ARN must be used as is, with the requested traffic type"
  }
  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0 && length(aws_iam_role.this) == 0 && length(aws_iam_role_policy.this) == 0
    error_message = "No log group or role is needed when flow logs go to S3"
  }
  assert {
    condition     = one(aws_flow_log.this.destination_options).file_format == "parquet" && one(aws_flow_log.this.destination_options).hive_compatible_partitions == true
    error_message = "destination_options must reach the flow log"
  }
}

run "firehose_destination_type_is_derived" {
  command = plan

  variables {
    flow_log = {
      vpc_key         = "main"
      log_destination = "arn:aws:firehose:ca-central-1:111111111111:deliverystream/central"
    }
  }

  assert {
    condition     = aws_flow_log.this.log_destination_type == "kinesis-data-firehose" && length(aws_iam_role.this) == 0
    error_message = "A Firehose ARN must give a kinesis-data-firehose destination and no CloudWatch role"
  }
}

run "given_cloudwatch_log_group_gets_a_role_for_it" {
  command = plan

  variables {
    flow_log = {
      vpc_key         = "main"
      log_destination = "arn:aws:logs:ca-central-1:111111111111:log-group:existing"
    }
  }

  assert {
    condition     = aws_flow_log.this.log_destination_type == "cloud-watch-logs" && length(aws_cloudwatch_log_group.this) == 0 && length(aws_iam_role.this) == 1
    error_message = "A given log group ARN is used as is and still needs a delivery role"
  }
}

run "destination_without_arn_must_be_cloudwatch" {
  command = plan

  variables {
    flow_log = {
      vpc_key              = "main"
      log_destination_type = "s3"
    }
  }

  expect_failures = [aws_flow_log.this]
}

# ---------------------------------------------------------------------------
# targets
# Exactly one of vpc_key, vpc_id, subnet_id, eni_id, regional_nat_gateway_id,
# transit_gateway_id, transit_gateway_attachment_id.
# ---------------------------------------------------------------------------
run "target_literal_vpc_id" {
  command = plan

  variables {
    flow_log = { vpc_id = "vpc-0aaaaaaaaaaaaaaaa" }
  }

  assert {
    condition     = aws_flow_log.this.vpc_id == "vpc-0aaaaaaaaaaaaaaaa"
    error_message = "A literal vpc_id must be used as is"
  }
}

run "target_subnet" {
  command = plan

  variables {
    flow_log = { subnet_id = "subnet-0123456789abcdef0" }
  }

  assert {
    condition     = aws_flow_log.this.subnet_id == "subnet-0123456789abcdef0" && aws_flow_log.this.traffic_type == "ALL"
    error_message = "A subnet flow log must keep the ALL traffic default"
  }
}

run "target_transit_gateway_has_no_traffic_type" {
  command = plan

  variables {
    flow_log = { transit_gateway_id = "tgw-0123456789abcdef0" }
  }

  assert {
    condition     = aws_flow_log.this.transit_gateway_id == "tgw-0123456789abcdef0" && aws_flow_log.this.traffic_type == null
    error_message = "A transit gateway flow log must not set traffic_type"
  }
}

run "target_none_is_rejected" {
  command = plan

  variables {
    flow_log = {}
  }

  expect_failures = [aws_flow_log.this]
}

run "target_two_is_rejected" {
  command = plan

  variables {
    flow_log = { vpc_key = "main", subnet_id = "subnet-0123456789abcdef0" }
  }

  expect_failures = [aws_flow_log.this]
}

run "unknown_vpc_key_is_rejected" {
  command = plan

  variables {
    flow_log = { vpc_key = "missing" }
  }

  expect_failures = [aws_flow_log.this]
}

# ---------------------------------------------------------------------------
# optional arguments
# ---------------------------------------------------------------------------
run "optional_arguments" {
  command = plan

  variables {
    flow_log = {
      vpc_key                  = "main"
      log_format               = "$${srcaddr} $${dstaddr} $${action}"
      max_aggregation_interval = 60
      tag_field_specification = [
        { resource_type = "instance", tag_keys = ["Name"] }
      ]
    }
  }

  assert {
    condition     = aws_flow_log.this.log_format == "$${srcaddr} $${dstaddr} $${action}" && aws_flow_log.this.max_aggregation_interval == 60
    error_message = "log_format and max_aggregation_interval must reach the flow log"
  }
  assert {
    condition     = length(aws_flow_log.this.tag_field_specification) == 1
    error_message = "tag_field_specification must reach the flow log"
  }
}

# ---------------------------------------------------------------------------
# optional_features_absent_by_default
# ---------------------------------------------------------------------------
run "optional_features_absent_by_default" {
  command = plan

  assert {
    condition     = aws_flow_log.this.max_aggregation_interval == null && aws_flow_log.this.deliver_cross_account_role == null
    error_message = "Optional arguments must be unset by default"
  }
  assert {
    condition     = length(aws_flow_log.this.destination_options) == 0 && length(aws_flow_log.this.tag_field_specification) == 0
    error_message = "Optional blocks must be absent by default"
  }
}

run "user_defined_string_without_letters_is_rejected" {
  command = plan

  variables {
    userDefinedString = "---"
  }

  expect_failures = [var.userDefinedString]
}
