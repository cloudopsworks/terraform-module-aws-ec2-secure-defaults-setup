##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

## Settings for the module - YAML format
# Explicit values always win over compliance-profile defaults.
# settings:
#   compliance:                      # (Optional) Compliance profiles aligned to AWS Security Hub CSPM standards.
#     cis: true                      # (Optional) CIS AWS Foundations Benchmark v3.0.0 / v5.0.0. Default: true
#     pci_dss: true                  # (Optional) PCI DSS v3.2.1 / v4.0.1. Default: true
#     ai_security: true              # (Optional) AWS AI Security Best Practices v1.0.0 supporting controls. Default: true
#     nist_800_53: false             # (Optional) NIST SP 800-53 Rev. 5 hardening. Default: false
#     exceptions: []                 # (Optional) Security Hub control IDs whose plan-time guard is waived (defaults still apply): EC2.1 (alias EC2.182), EC2.7, EC2.8, KMS.4, S3.1. Default: []
#   instance_metadata:               # (Optional) Account-level EC2 instance metadata defaults (supports EC2.8).
#     http_endpoint: "enabled"       # (Optional) "enabled" | "disabled" | "no-preference". Default: "enabled"
#     http_tokens: "required"        # (Optional) "required" | "optional" | "no-preference". Default: "required"; must stay "required" under cis, pci_dss, nist_800_53
#     http_put_response_hop_limit: 1 # (Optional) 1-64 or -1 (no preference). Default: no preference. Use 1 for strictest; 2 only where containers need IMDS
#     tags: "disabled"               # (Optional) "enabled" | "disabled" | "no-preference". Default: no preference
#   ec2:                             # (Optional) EC2 account attributes.
#     image_block_public_access: "block-new-sharing" # (Optional) "block-new-sharing" | "unblocked". Default: "block-new-sharing" under pci_dss, ai_security, nist_800_53, otherwise unmanaged
#     serial_console_access: false   # (Optional) true | false. Default: false under nist_800_53, otherwise unmanaged
#     allowed_images:                # (Optional) Allowed AMIs account setting (NIST CM-7(5)). Default: unmanaged; removing the block disables it
#       state: "audit-mode"          # (Required when set) "enabled" | "audit-mode". Start with "audit-mode"
#       criteria:                    # (Required when state is "enabled") An AMI is allowed when it matches any entry
#         - image_providers: ["amazon"]      # (Optional) "amazon", "aws-marketplace", "aws-backup-vault" or 12-digit account IDs
#           image_names: ["al2023-ami-*"]    # (Optional) AMI name patterns, wildcards * and ?
#           marketplace_product_codes: []    # (Optional) AWS Marketplace product codes
#           maximum_days_since_created: 365  # (Optional) Max AMI age in days
#           maximum_days_since_deprecated: 0 # (Optional) Max days since AMI deprecation
#   ebs:                             # (Optional) EBS account defaults.
#     encryption_by_default: true    # (Optional) EC2.7. Default: true; must stay true under cis, nist_800_53
#     snapshot_block_public_access: "block-all-sharing" # (Optional) "block-all-sharing" | "block-new-sharing" | "unblocked". Default: "block-all-sharing"; must stay "block-all-sharing" under pci_dss, nist_800_53
#     default_kms_key:               # (Optional) Module-managed customer managed KMS key set as the account EBS default (protected by prevent_destroy).
#       enabled: true                # (Optional) Default: true under ai_security, nist_800_53, otherwise false. Once applied, keep true (see upgrade notes)
#       deletion_window_in_days: 30  # (Optional) 7-30. Default: 30
#       enable_key_rotation: true    # (Optional) KMS.4. Default: true; must stay true under cis, pci_dss, nist_800_53
#       rotation_period_in_days: 90  # (Optional) Rotation interval in days, 90-2560. Default: 90
#       is_enabled: true             # (Optional) Default: true
#       policy_documents: []         # (Optional) Extra key policy JSON documents merged into the module policy (e.g. cross-account snapshot sharing). Default: []
#   vpc:                             # (Optional) VPC account settings.
#     configure_public_access: false # (Optional) Manage VPC Block Public Access (EC2.172). Default: false
#     block_public_access: "off"     # (Optional) "block-bidirectional" | "block-ingress" | "off". Default: "off"
#     exclusions:                    # (Optional) VPC Block Public Access exclusions. Default: []
#       - mode: "allow-egress"       # (Optional) "allow-egress" | "allow-bidirectional". Default: "allow-egress"
#         vpc_id: "vpc-12345678"     # (Optional) VPC to exclude; set either vpc_id or subnet_id
#         subnet_id: "subnet-12345678" # (Optional) Subnet to exclude; takes precedence over vpc_id
#     restrict_default_vpc_security_group: false # (Optional) Remove all rules from the default VPC's default security group (EC2.2). Default: false
#   s3:                              # (Optional) S3 account-level Block Public Access (S3.1). Global setting: own it from one regional deployment only.
#     manage_account_settings: true  # (Optional) This deployment owns account-wide S3 settings. Set false in every other region. Default: true
#     configure_public_access: true  # (Optional) Default: true under cis, pci_dss, nist_800_53 when manage_account_settings, otherwise false
#     block_public_acls: true        # (Optional) Default: true under cis, pci_dss, nist_800_53 when manage_account_settings
#     block_public_policy: true      # (Optional) Default: true under cis, pci_dss, nist_800_53 when manage_account_settings
#     ignore_public_acls: true       # (Optional) Default: true under cis, pci_dss, nist_800_53 when manage_account_settings
#     restrict_public_buckets: true  # (Optional) Default: true under cis, pci_dss, nist_800_53 when manage_account_settings
variable "settings" {
  description = "(Optional) Account-level EC2, EBS, VPC and S3 secure defaults with compliance profiles (CIS, PCI DSS, AI Security on; NIST 800-53 off). Default: {}"
  type        = any
  default     = {}
}
