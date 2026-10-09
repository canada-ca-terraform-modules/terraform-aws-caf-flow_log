# terraform-aws-caf-flow_log

VPC flow logs for the ESLZ AWS landing zones, with the supporting resources CloudWatch Logs delivery needs. Structure follows `terraform-azurerm-caf-linux_virtual_machineV2` and the other `terraform-aws-caf-*` modules.

Aligned with [aws provider 6.68.0](https://registry.terraform.io/providers/hashicorp/aws/6.68.0/docs/resources/flow_log): every `aws_flow_log` argument and nested block is reachable through the single `flow_log` object.

## Scope

| Always created | Created when |
| --- | --- |
| `aws_flow_log` | n/a |
| `aws_cloudwatch_log_group` | no `log_destination` is set |
| `aws_iam_role`, `aws_iam_role_policy` | the destination is CloudWatch Logs and no `iam_role_arn` is set |

Resources outside the `aws_flow_log` prefix that are included here because they are created and consumed with the flow log: the log group and the delivery role with its policy.

Excluded on purpose:

- `aws_flow_log` `region` argument: set the region on the provider.
- The S3 bucket, Firehose stream and KMS key a destination may need: they belong to the central logging stack, and the module only takes their ARNs.

## Usage

```hcl
module "flow_log" {
  source   = "github.com/canada-ca-terraform-modules/terraform-aws-caf-flow_log.git?ref=v1.0.0"
  for_each = var.flow_logs

  userDefinedString = each.key
  env               = var.env
  vpc_ids           = { for k, v in module.vpc : k => v.id }
  flow_log          = each.value
  tags              = var.tags
}
```

Each flow log sets exactly one target. `vpc_key` resolves through `vpc_ids` (VPC key to ID); a literal `vpc_id`, `subnet_id`, `eni_id`, `regional_nat_gateway_id`, `transit_gateway_id` or `transit_gateway_attachment_id` is used as is. An unknown `vpc_key`, no target, or more than one target fails the plan.

Naming: `<env>-<userDefinedString>-<suffix>` using the suffixes from `Documentation/Standards/AWS-Naming-and-Tagging-Suffixes.md` (`flowlog` for the Name tag, `role`, `log`). The log group is `/vpc/flow-logs/<env>-<userDefinedString>-log`. Set `flow_log.name` to replace the flow log name; the role and log group then derive from it. See `ESLZ/flow_log.tfvars` for a complete example.

## TFVars Parameters

### Flow log (`flow_log`)

| Key | Type | Required | Default |
| --- | --- | --- | --- |
| name | string, custom name (lowercased; only `a-z0-9-` kept) | No | `<env>-<userDefinedString>-flowlog` |
| vpc_key | key in `vpc_ids` | Exactly one target | n/a |
| vpc_id, subnet_id, eni_id, regional_nat_gateway_id, transit_gateway_id, transit_gateway_attachment_id | literal ID | See above | n/a |
| traffic_type | ACCEPT, REJECT, ALL | No | `ALL`; unset for transit gateway targets |
| log_destination | ARN of an S3 bucket, Firehose stream or CloudWatch log group | No | the log group the module creates |
| log_destination_type | cloud-watch-logs, s3, kinesis-data-firehose | No | derived from `log_destination`, else `cloud-watch-logs` |
| iam_role_arn | role ARN for CloudWatch delivery | No | a role the module creates |
| log_format | string | No | provider default |
| max_aggregation_interval | 60, 600 | No | provider default |
| deliver_cross_account_role | role ARN | No | none |
| destination_options | `{ file_format, hive_compatible_partitions, per_hour_partition }` (S3 only) | No | none |
| tag_field_specification | list of `{ resource_type, tag_keys }` | No | none |
| tags | map(string), merged over the module `tags` | No | {} |

### Log group (`flow_log.cloudwatch_log_group`)

| Key | Type | Required | Default |
| --- | --- | --- | --- |
| name | string, custom name (lowercased; only `a-z0-9._#/-` kept) | No | `/vpc/flow-logs/<base>-log` |
| retention_in_days | number | No | 731 |
| kms_key_id, log_group_class, skip_destroy | see provider docs | No | provider default |
| tags | map(string) | No | {} |

### IAM (`flow_log.iam_role`)

| Key | Type | Required | Default |
| --- | --- | --- | --- |
| name | string, custom name (lowercased; only `a-z0-9-` kept) | No | `<base>-role` |
| assume_role_policy | JSON | No | trusts `vpc-flow-logs.amazonaws.com`, limited to this account |
| description, path, permissions_boundary | see provider docs | No | provider default |
| tags | map(string) | No | {} |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.68.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_env"></a> [env](#input\_env) | (Required) env value used in name generation | `string` | n/a | yes |
| <a name="input_flow_log"></a> [flow\_log](#input\_flow\_log) | (Required) Object describing the flow log (see TFVars Parameters in the README). Optional `name` key overrides the auto-derived name. | `any` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources (merged with flow\_log.tags) | `map(string)` | `{}` | no |
| <a name="input_userDefinedString"></a> [userDefinedString](#input\_userDefinedString) | (Required) UserDefinedString part of the name of the flow log | `string` | n/a | yes |
| <a name="input_vpc_ids"></a> [vpc\_ids](#input\_vpc\_ids) | Optional map of VPC key to its ID. Resolves flow\_log.vpc\_key. e.g. { for k, v in module.vpc : k => v.id } | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | Returns the ARN of the flow log |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | Returns the ARN of the role that delivers to CloudWatch Logs, or null when none is used |
| <a name="output_id"></a> [id](#output\_id) | Returns the ID of the flow log |
| <a name="output_log_destination"></a> [log\_destination](#output\_log\_destination) | Returns the ARN the flow log delivers to: the created log group, or the given log\_destination |
| <a name="output_name"></a> [name](#output\_name) | Returns the Name tag of the flow log |
| <a name="output_object"></a> [object](#output\_object) | Returns the full aws\_flow\_log resource object |
<!-- END_TF_DOCS -->
