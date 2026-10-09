data "aws_caller_identity" "current" {}

# Created for CloudWatch Logs delivery unless iam_role_arn is given.
resource "aws_iam_role" "this" {
  for_each = local.role-instances

  name                 = local.role-name
  description          = try(var.flow_log.iam_role.description, null)
  path                 = try(var.flow_log.iam_role.path, null)
  permissions_boundary = try(var.flow_log.iam_role.permissions_boundary, null)
  assume_role_policy = try(var.flow_log.iam_role.assume_role_policy, jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  }))

  # Tags - Merging tags provided by ESLZ with tags provided by the user
  tags = merge(var.tags, try(var.flow_log.iam_role.tags, {}), local.module_tag, { Name = local.role-name })
}

resource "aws_iam_role_policy" "this" {
  for_each = local.role-instances

  name = "deliver-flow-logs"
  role = aws_iam_role.this[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = [local.log-destination, "${local.log-destination}:*"]
    }]
  })
}
