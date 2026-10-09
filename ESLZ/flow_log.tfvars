## One example instance per key; the key becomes userDefinedString (name: <env>-<key>-flowlog).
## Group headings match the module's .tf files. Every optional key is listed commented out.

flow_logs = {
  example01 = {
    # Pick exactly ONE target: vpc_key (a key of vpc_ids) or one literal ID.
    vpc_key = "client1"
    # vpc_id                        = "vpc-0123456789abcdef0"
    # subnet_id                     = "subnet-0123456789abcdef0"
    # eni_id                        = "eni-0123456789abcdef0"
    # regional_nat_gateway_id       = "nat-0123456789abcdef0"
    # transit_gateway_id            = "tgw-0123456789abcdef0"            # no traffic_type for transit gateways
    # transit_gateway_attachment_id = "tgw-attach-0123456789abcdef0"

    # traffic_type = "ALL" # ACCEPT, REJECT or ALL (default ALL; unset for transit gateways)

    # --- module.tf ---
    # log_destination      = "arn:aws:s3:::central-log-archive/flow-logs/" # omit to log to a log group the module creates
    # log_destination_type = "s3"                                          # cloud-watch-logs, s3 or kinesis-data-firehose; derived from log_destination
    # iam_role_arn         = "arn:aws:iam::123456789012:role/existing"     # CloudWatch delivery role; omit to create one
    # log_format                 = "$${srcaddr} $${dstaddr} $${action}"
    # max_aggregation_interval   = 60                                     # 60 or 600
    # deliver_cross_account_role = "arn:aws:iam::123456789012:role/central"
    # destination_options = { file_format = "parquet", hive_compatible_partitions = true, per_hour_partition = true } # s3 only
    # tag_field_specification = [{ resource_type = "instance", tag_keys = ["Name"] }]
    # name = "custom-name" # replaces the flow log Name tag; role and log group names derive from it
    # tags = { owner = "team-x" }

    # --- cloudwatch.tf (created when no log_destination is set) ---
    # cloudwatch_log_group = {
    #   retention_in_days = 731 # default 731 (two years)
    #   # kms_key_id / log_group_class / skip_destroy / name / tags
    # }

    # --- iam.tf (created for CloudWatch Logs unless iam_role_arn is set) ---
    # iam_role = {
    #   # assume_role_policy   = "<json>" # default trusts vpc-flow-logs.amazonaws.com for this account
    #   # description / path / permissions_boundary / name / tags
    # }
  }
}
