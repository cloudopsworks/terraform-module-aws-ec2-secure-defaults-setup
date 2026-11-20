##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

# Compliance profiles resolve the effective defaults of every setting in this module.
# Explicit values under var.settings always win over a profile default; the guard at the
# bottom of this file fails the plan when an explicit value contradicts an active framework,
# unless the matching AWS Security Hub control ID is listed in settings.compliance.exceptions.
locals {
  compliance = {
    cis         = coalesce(try(var.settings.compliance.cis, null), true)
    pci_dss     = coalesce(try(var.settings.compliance.pci_dss, null), true)
    ai_security = coalesce(try(var.settings.compliance.ai_security, null), true)
    nist_800_53 = coalesce(try(var.settings.compliance.nist_800_53, null), false)
  }

  # Waivable Security Hub controls; aliases map to the control the guard evaluates.
  compliance_supported_exceptions = ["EC2.1", "EC2.7", "EC2.8", "EC2.182", "KMS.4", "S3.1"]
  compliance_exception_aliases    = { "EC2.182" = "EC2.1" }
  compliance_exceptions_input     = toset([for control in coalesce(try(var.settings.compliance.exceptions, null), []) : upper(control)])
  compliance_exceptions           = toset([for control in local.compliance_exceptions_input : lookup(local.compliance_exception_aliases, control, control)])

  # Security Hub controls checked by the guard (exceptions waive the guard only, never the default).
  # Framework membership follows each control's "Related requirements" in the Security Hub CSPM user guide.
  # The guard checks this module's account defaults; per-resource findings (e.g. EC2.8 on an instance
  # launched with http_tokens=optional) still need SCPs or EC2 declarative policies to prevent.
  enforce_imdsv2         = (local.compliance.cis || local.compliance.pci_dss || local.compliance.nist_800_53) && !contains(local.compliance_exceptions, "EC2.8")
  enforce_ebs_encryption = (local.compliance.cis || local.compliance.nist_800_53) && !contains(local.compliance_exceptions, "EC2.7")
  enforce_kms_rotation   = (local.compliance.cis || local.compliance.pci_dss || local.compliance.nist_800_53) && !contains(local.compliance_exceptions, "KMS.4")
  enforce_snapshot_bpa   = (local.compliance.pci_dss || local.compliance.nist_800_53) && !contains(local.compliance_exceptions, "EC2.1")
  require_s3_bpa         = (local.compliance.cis || local.compliance.pci_dss || local.compliance.nist_800_53) && local.s3_manage_account_settings
  enforce_s3_bpa         = local.require_s3_bpa && !contains(local.compliance_exceptions, "S3.1")

  # Supporting controls: hardened defaults without a Security Hub control ID to enforce.
  default_ebs_cmk               = local.compliance.ai_security || local.compliance.nist_800_53
  default_ami_block_public      = local.compliance.pci_dss || local.compliance.ai_security || local.compliance.nist_800_53
  default_serial_console_off    = local.compliance.nist_800_53
  default_long_log_retention    = local.compliance.pci_dss || local.compliance.nist_800_53
  default_automation_logs_cmk   = local.compliance.nist_800_53
  log_retention_days_default    = 90
  log_retention_days_compliance = 365 # PCI DSS 10.5.1 (12 months of audit history), NIST AU-11
  kms_deletion_window_days      = 30
  kms_rotation_period_days      = 365

  # Effective settings
  imds_http_tokens          = try(var.settings.instance_metadata.http_tokens, "required")
  imds_hop_limit            = try(var.settings.instance_metadata.http_put_response_hop_limit, null)
  ebs_encryption_by_default = coalesce(try(var.settings.ebs.encryption_by_default, null), true)
  ebs_kms_key_enabled       = try(var.settings.ebs.default_kms_key.enabled, local.default_ebs_cmk)
  ebs_kms_key_rotation      = try(var.settings.ebs.default_kms_key.enable_key_rotation, true)
  snapshot_bpa_state        = try(var.settings.ebs.snapshot_block_public_access, "block-all-sharing")
  ami_bpa_state             = try(var.settings.ec2.image_block_public_access, local.default_ami_block_public ? "block-new-sharing" : null)
  serial_console_enabled    = try(var.settings.ec2.serial_console_access, local.default_serial_console_off ? false : null)
  # S3 account Block Public Access is global: only one regional deployment per account should own it.
  s3_manage_account_settings = coalesce(try(var.settings.s3.manage_account_settings, null), true)
  s3_configure_public        = try(var.settings.s3.configure_public_access, local.require_s3_bpa)
  s3_public_access_block = {
    for flag in ["block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"] :
    flag => try(var.settings.s3[flag], local.require_s3_bpa ? true : null)
  }

  automation_log_group_name        = "/aws/ssm/automation/${local.system_name}"
  automation_logs_retention        = try(var.settings.ssm.automation_logs.retention_in_days, local.default_long_log_retention ? local.log_retention_days_compliance : local.log_retention_days_default)
  automation_logs_kms_key_arn_in   = try(var.settings.ssm.automation_logs.kms_key.arn, "")
  automation_logs_create_kms_key   = local.automation_logs_kms_key_arn_in == "" && try(var.settings.ssm.automation_logs.kms_key.enabled, local.default_automation_logs_cmk)
  automation_logs_kms_key_rotation = try(var.settings.ssm.automation_logs.kms_key.enable_key_rotation, true)
  automation_logs_kms_key_arn      = local.automation_logs_create_kms_key ? aws_kms_key.automation_logs[0].arn : (local.automation_logs_kms_key_arn_in != "" ? local.automation_logs_kms_key_arn_in : null)

  allowed_images_state    = try(var.settings.ec2.allowed_images.state, "")
  allowed_images_criteria = try({ for idx, criterion in var.settings.ec2.allowed_images.criteria : tostring(idx) => criterion }, {})
}

resource "terraform_data" "compliance_guard" {
  input = {
    frameworks = local.compliance
    exceptions = sort(tolist(local.compliance_exceptions))
  }

  lifecycle {
    precondition {
      condition     = length(setsubtract(local.compliance_exceptions_input, local.compliance_supported_exceptions)) == 0
      error_message = "settings.compliance.exceptions only accepts these Security Hub control IDs: EC2.1 (alias EC2.182), EC2.7, EC2.8, KMS.4, S3.1."
    }
    precondition {
      condition     = local.allowed_images_state != "enabled" || length(local.allowed_images_criteria) > 0
      error_message = "settings.ec2.allowed_images.criteria must not be empty when state is \"enabled\"; an empty allow-list blocks every AMI launch. Use \"audit-mode\" first."
    }
    precondition {
      condition     = !local.enforce_imdsv2 || local.imds_http_tokens == "required"
      error_message = "EC2.8 (CIS v5 5.7 / v3 5.6, PCI DSS 2.2.6, NIST AC-3): settings.instance_metadata.http_tokens must be \"required\" while cis, pci_dss or nist_800_53 is enabled. Disable those frameworks or add \"EC2.8\" to settings.compliance.exceptions."
    }
    precondition {
      condition     = !local.enforce_ebs_encryption || local.ebs_encryption_by_default
      error_message = "EC2.7 (CIS v5 5.1.1 / v3 2.2.1, NIST SC-28): settings.ebs.encryption_by_default must be true while cis or nist_800_53 is enabled. Disable those frameworks or add \"EC2.7\" to settings.compliance.exceptions."
    }
    precondition {
      condition     = !local.enforce_kms_rotation || ((!local.ebs_kms_key_enabled || local.ebs_kms_key_rotation) && (!local.automation_logs_create_kms_key || local.automation_logs_kms_key_rotation))
      error_message = "KMS.4 (CIS 3.6, PCI DSS 3.7.4, NIST SC-12): module-managed KMS keys must have enable_key_rotation = true while cis, pci_dss or nist_800_53 is enabled. Disable those frameworks or add \"KMS.4\" to settings.compliance.exceptions."
    }
    precondition {
      condition     = !local.enforce_snapshot_bpa || local.snapshot_bpa_state == "block-all-sharing"
      error_message = "EC2.1 / EC2.182 (PCI DSS v3.2.1 1.3.1, 7.2.1, NIST AC-3, SC-7): settings.ebs.snapshot_block_public_access must be \"block-all-sharing\" while pci_dss or nist_800_53 is enabled; \"block-new-sharing\" leaves existing public snapshots public. Disable those frameworks or add \"EC2.1\" to settings.compliance.exceptions."
    }
    precondition {
      condition     = !local.enforce_s3_bpa || (local.s3_configure_public && alltrue([for flag, value in local.s3_public_access_block : value == true]))
      error_message = "S3.1 (CIS 2.1.4, PCI DSS 1.4.4, NIST AC-3, SC-7): in the deployment that owns account settings (settings.s3.manage_account_settings), settings.s3 must keep configure_public_access and all four block/ignore/restrict flags true while cis, pci_dss or nist_800_53 is enabled. Disable those frameworks or add \"S3.1\" to settings.compliance.exceptions."
    }
  }
}
