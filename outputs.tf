##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

output "ebs_kms_key_id" {
  value = try(var.settings.ebs.default_kms_key.enabled, false) ? aws_kms_key.ebs_key[0].id : null
}

output "ebs_kms_key_arn" {
  value = try(var.settings.ebs.default_kms_key.enabled, false) ? aws_kms_key.ebs_key[0].arn : null
}

output "ebs_kms_key_alias" {
  value = try(var.settings.ebs.default_kms_key.enabled, false) ? aws_kms_alias.ebs_key[0].name : null
}