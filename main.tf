##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

## EC2 instance metadata (IMDSv2) - account default supporting EC2.8
resource "aws_ec2_instance_metadata_defaults" "this" {
  http_endpoint               = try(var.settings.instance_metadata.http_endpoint, "enabled")
  http_tokens                 = local.imds_http_tokens
  http_put_response_hop_limit = local.imds_hop_limit
  instance_metadata_tags      = try(var.settings.instance_metadata.tags, null)
}

## EC2 account attributes - AMI public sharing, serial console, allowed AMIs
resource "aws_ec2_image_block_public_access" "this" {
  count = local.ami_bpa_state != null ? 1 : 0
  state = local.ami_bpa_state
}

resource "aws_ec2_serial_console_access" "this" {
  count   = local.serial_console_enabled != null ? 1 : 0
  enabled = local.serial_console_enabled
}

resource "aws_ec2_allowed_images_settings" "this" {
  count = local.allowed_images_state != "" ? 1 : 0
  state = local.allowed_images_state

  dynamic "image_criterion" {
    for_each = local.allowed_images_criteria
    content {
      image_providers           = try(image_criterion.value.image_providers, null)
      image_names               = try(image_criterion.value.image_names, null)
      marketplace_product_codes = try(image_criterion.value.marketplace_product_codes, null)

      dynamic "creation_date_condition" {
        for_each = try(image_criterion.value.maximum_days_since_created, null) != null ? [1] : []
        content {
          maximum_days_since_created = image_criterion.value.maximum_days_since_created
        }
      }

      dynamic "deprecation_time_condition" {
        for_each = try(image_criterion.value.maximum_days_since_deprecated, null) != null ? [1] : []
        content {
          maximum_days_since_deprecated = image_criterion.value.maximum_days_since_deprecated
        }
      }
    }
  }
}

## EBS - encryption by default (EC2.7), default CMK (KMS.4), snapshot public sharing (EC2.1 / EC2.182)
resource "aws_ebs_encryption_by_default" "this" {
  enabled = local.ebs_encryption_by_default
}

data "aws_iam_policy_document" "ebs_kms" {
  count = local.ebs_kms_key_enabled ? 1 : 0
  # Extra statements (e.g. cross-account snapshot sharing) supplied as JSON policy documents.
  source_policy_documents = coalesce(try(var.settings.ebs.default_kms_key.policy_documents, null), [])

  statement {
    sid       = "EnableAccountIamPolicies"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.account_root_arn]
    }
  }

  # Mirrors the AWS managed aws/ebs key: any principal of this account may use the key, but only
  # through EC2. Keeps RunInstances/CreateVolume working for roles (and the Auto Scaling, Spot,
  # EC2 Fleet and EKS service-linked roles) that have no explicit KMS permissions.
  statement {
    sid       = "AllowAccountUseThroughEc2"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:CreateGrant", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_kms_key" "ebs_key" {
  count                   = local.ebs_kms_key_enabled ? 1 : 0
  description             = "Default EBS KMS key for the account"
  deletion_window_in_days = try(var.settings.ebs.default_kms_key.deletion_window_in_days, local.kms_deletion_window_days)
  enable_key_rotation     = local.ebs_kms_key_rotation
  rotation_period_in_days = local.ebs_kms_key_rotation ? try(var.settings.ebs.default_kms_key.rotation_period_in_days, local.kms_rotation_period_days) : null
  is_enabled              = try(var.settings.ebs.default_kms_key.is_enabled, true)
  policy                  = data.aws_iam_policy_document.ebs_kms[0].json
  tags                    = local.all_tags

  # Volumes, snapshots and AMIs encrypted with this key become unrecoverable once it is deleted.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "ebs_key" {
  count         = local.ebs_kms_key_enabled ? 1 : 0
  target_key_id = aws_kms_key.ebs_key[0].id
  name          = "alias/ebs-${local.system_name}"
}

resource "aws_ebs_default_kms_key" "this" {
  count   = local.ebs_kms_key_enabled ? 1 : 0
  key_arn = aws_kms_key.ebs_key[0].arn
}

resource "aws_ebs_snapshot_block_public_access" "this" {
  state = local.snapshot_bpa_state
}

## VPC - Block Public Access (EC2.172) and default-VPC default security group (EC2.2)
resource "aws_vpc_block_public_access_options" "this" {
  count                       = try(var.settings.vpc.configure_public_access, false) ? 1 : 0
  internet_gateway_block_mode = try(var.settings.vpc.block_public_access, "off")
}

resource "aws_vpc_block_public_access_exclusion" "this_vpcs" {
  for_each = {
    for exclusion in try(var.settings.vpc.exclusions, []) : exclusion.vpc_id => exclusion
    if try(exclusion.vpc_id, "") != "" && try(exclusion.subnet_id, "") == "" && try(var.settings.vpc.configure_public_access, false)
  }
  internet_gateway_exclusion_mode = try(each.value.mode, "allow-egress")
  vpc_id                          = each.value.vpc_id
  tags                            = local.all_tags
}

resource "aws_vpc_block_public_access_exclusion" "this_subnets" {
  for_each = {
    for exclusion in try(var.settings.vpc.exclusions, []) : exclusion.subnet_id => exclusion
    if try(exclusion.subnet_id, "") != "" && try(var.settings.vpc.configure_public_access, false)
  }
  internet_gateway_exclusion_mode = try(each.value.mode, "allow-egress")
  subnet_id                       = each.value.subnet_id
  tags                            = local.all_tags
}

# Only the region's default VPC is handled here; VPCs created by terraform-aws-vpc-setup
# manage their own default security groups.
data "aws_vpcs" "default" {
  count = try(var.settings.vpc.restrict_default_vpc_security_group, false) ? 1 : 0
  filter {
    name   = "is-default"
    values = ["true"]
  }
}

resource "aws_default_security_group" "default_vpc" {
  for_each = toset(try(data.aws_vpcs.default[0].ids, []))
  vpc_id   = each.value
  tags     = local.all_tags
}

## S3 account-level Block Public Access - S3.1
resource "aws_s3_account_public_access_block" "this" {
  count                   = local.s3_configure_public ? 1 : 0
  block_public_acls       = local.s3_public_access_block.block_public_acls
  block_public_policy     = local.s3_public_access_block.block_public_policy
  ignore_public_acls      = local.s3_public_access_block.ignore_public_acls
  restrict_public_buckets = local.s3_public_access_block.restrict_public_buckets
}

## SSM - document public sharing (SSM.7) and Automation logging (SSM.6)
moved {
  from = aws_ssm_service_setting.this
  to   = aws_ssm_service_setting.public_sharing_permission
}
resource "aws_ssm_service_setting" "public_sharing_permission" {
  setting_id    = "/ssm/documents/console/public-sharing-permission"
  setting_value = "Disable"
}

resource "aws_ssm_service_setting" "script_log_destination" {
  setting_id    = "/ssm/automation/customer-script-log-destination"
  setting_value = "CloudWatch"
}

data "aws_iam_policy_document" "automation_logs_kms" {
  count = local.automation_logs_create_kms_key ? 1 : 0

  statement {
    sid       = "EnableAccountIamPolicies"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.account_root_arn]
    }
  }

  statement {
    sid       = "AllowCloudWatchLogsForAutomationLogGroup"
    effect    = "Allow"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.automation_log_group_name}"]
    }
  }
}

resource "aws_kms_key" "automation_logs" {
  count                   = local.automation_logs_create_kms_key ? 1 : 0
  description             = "SSM Automation CloudWatch Logs encryption key"
  deletion_window_in_days = try(var.settings.ssm.automation_logs.kms_key.deletion_window_in_days, local.kms_deletion_window_days)
  enable_key_rotation     = local.automation_logs_kms_key_rotation
  rotation_period_in_days = local.automation_logs_kms_key_rotation ? try(var.settings.ssm.automation_logs.kms_key.rotation_period_in_days, local.kms_rotation_period_days) : null
  policy                  = data.aws_iam_policy_document.automation_logs_kms[0].json
  tags                    = local.all_tags

  # Encrypted audit logs become unreadable once the key is deleted.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "automation_logs" {
  count         = local.automation_logs_create_kms_key ? 1 : 0
  target_key_id = aws_kms_key.automation_logs[0].id
  name          = "alias/logs-ssm-automation-${local.system_name}"
}

resource "aws_cloudwatch_log_group" "script_log_destination_name" {
  name              = local.automation_log_group_name
  retention_in_days = local.automation_logs_retention
  kms_key_id        = local.automation_logs_kms_key_arn
  tags              = local.all_tags
}

resource "aws_ssm_service_setting" "script_log_destination_name" {
  setting_id    = "/ssm/automation/customer-script-log-group-name"
  setting_value = aws_cloudwatch_log_group.script_log_destination_name.name
}
