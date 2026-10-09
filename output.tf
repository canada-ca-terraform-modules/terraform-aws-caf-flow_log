output "object" {
  description = "Returns the full aws_flow_log resource object"
  value       = aws_flow_log.this
  sensitive   = true # legacy/deprecated attributes on some resources warn when exposed - harmless
}

output "id" {
  description = "Returns the ID of the flow log"
  value       = aws_flow_log.this.id
}

output "arn" {
  description = "Returns the ARN of the flow log"
  value       = aws_flow_log.this.arn
}

output "name" {
  description = "Returns the Name tag of the flow log"
  value       = local.flow-log-name
}

# --- resource-specific outputs below this line ---

output "log_destination" {
  description = "Returns the ARN the flow log delivers to: the created log group, or the given log_destination"
  value       = aws_flow_log.this.log_destination
}

output "iam_role_arn" {
  description = "Returns the ARN of the role that delivers to CloudWatch Logs, or null when none is used"
  value       = aws_flow_log.this.iam_role_arn
}
