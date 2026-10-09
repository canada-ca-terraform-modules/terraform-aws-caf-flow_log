# Changelog

## v1.0.0

- Initial release, aligned with aws provider 6.68.0.
- `aws_flow_log` with every argument and nested block exposed through the single `flow_log` object, on a VPC, subnet, network interface, regional NAT gateway, transit gateway or transit gateway attachment.
- Without a `log_destination`, a CloudWatch log group (731-day retention) and a delivery role are created; with an S3 or Firehose ARN nothing else is created.
