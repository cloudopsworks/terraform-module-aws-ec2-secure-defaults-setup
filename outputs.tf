##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

output "compliance_frameworks" {
  description = "Compliance frameworks active for this deployment (cis, pci_dss, ai_security, nist_800_53)."
  value       = local.compliance
}

output "compliance_exceptions" {
  description = "AWS Security Hub control IDs waived through settings.compliance.exceptions."
  value       = sort(tolist(local.compliance_exceptions))
}

output "ebs_kms_key_id" {
  description = "ID of the module-managed default EBS KMS key, or null when the module does not create one."
  value       = local.ebs_kms_key_enabled ? aws_kms_key.ebs_key[0].id : null
}

output "ebs_kms_key_arn" {
  description = "ARN of the module-managed default EBS KMS key, or null when the module does not create one."
  value       = local.ebs_kms_key_enabled ? aws_kms_key.ebs_key[0].arn : null
}

output "ebs_kms_key_alias" {
  description = "Alias of the module-managed default EBS KMS key, or null when the module does not create one."
  value       = local.ebs_kms_key_enabled ? aws_kms_alias.ebs_key[0].name : null
}

output "ssm_automation_log_group_name" {
  description = "Name of the CloudWatch log group receiving SSM Automation script output."
  value       = aws_cloudwatch_log_group.script_log_destination_name.name
}

output "ssm_automation_log_group_arn" {
  description = "ARN of the CloudWatch log group receiving SSM Automation script output."
  value       = aws_cloudwatch_log_group.script_log_destination_name.arn
}

output "ssm_automation_logs_kms_key_arn" {
  description = "ARN of the KMS key encrypting the SSM Automation log group, or null when the log group uses CloudWatch-managed encryption."
  value       = local.automation_logs_kms_key_arn
}
