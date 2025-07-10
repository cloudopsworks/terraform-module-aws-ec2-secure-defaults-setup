##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

resource "aws_ec2_instance_metadata_defaults" "this" {
  http_endpoint               = try(var.settings.instance_metadata.http_endpoint, "enabled")
  http_tokens                 = try(var.settings.instance_metadata.http_tokens, "required")
  http_put_response_hop_limit = try(var.settings.instance_metadata.http_put_response_hop_limit, null)
  instance_metadata_tags      = try(var.settings.instance_metadata.tags, null)
}

resource "aws_ebs_encryption_by_default" "this" {
  enabled = try(var.settings.ebs.encryption_by_default, true)
}

resource "aws_kms_key" "ebs_key" {
  count                   = try(var.settings.ebs.default_kms_key.enabled, false) ? 1 : 0
  description             = "Default EBS KMS key for the account"
  deletion_window_in_days = try(var.settings.ebs.default_kms_key.deletion_window_in_days, 30)
  enable_key_rotation     = try(var.settings.ebs.default_kms_key.enable_key_rotation, true)
  rotation_period_in_days = try(var.settings.ebs.default_kms_key.rotation_period_in_days, 365)
  is_enabled              = try(var.settings.ebs.default_kms_key.is_enabled, true)
  tags                    = local.all_tags
}

resource "aws_kms_alias" "ebs_key" {
  count         = try(var.settings.ebs.default_kms_key.enabled, false) ? 1 : 0
  target_key_id = aws_kms_key.ebs_key[0].id
  name          = "alias/ebs-${local.system_name}"
}

resource "aws_ebs_default_kms_key" "this" {
  count   = try(var.settings.ebs.default_kms_key.enabled, false) ? 1 : 0
  key_arn = aws_kms_key.ebs_key[0].arn
}

resource "aws_ebs_snapshot_block_public_access" "this" {
  state = try(var.settings.ebs.snapshot_block_public_access, "block-all-sharing")
}

resource "aws_vpc_block_public_access_options" "this" {
  count                       = try(var.settings.vpc.configure_public_access, false) ? 1 : 0
  internet_gateway_block_mode = try(var.settings.vpc.block_public_access, "off")
}

resource "aws_vpc_block_public_access_exclusion" "this_vpcs" {
  for_each = {
    for exclusion in try(var.settings.vpc.exclusions, []) : exclusion.vpc_id => exclusion
    if try(exclusion.vpc_id, "") != "" && try(var.settings.vpc.configure_public_access, false)
  }
  internet_gateway_exclusion_mode = try(each.value.mode, "allow-ingress")
  vpc_id                          = try(each.value.vpc_id, null)
  tags                            = local.all_tags
}

resource "aws_vpc_block_public_access_exclusion" "this_subnets" {
  for_each = {
    for exclusion in try(var.settings.vpc.exclusions, []) : exclusion.subnet_id => exclusion
    if try(exclusion.subnet_id, "") != "" && try(var.settings.vpc.configure_public_access, false)
  }
  internet_gateway_exclusion_mode = try(each.value.mode, "allow-ingress")
  vpc_id                          = try(each.value.vpc_id, null)
  subnet_id                       = try(each.value.subnet_id, null)
  tags                            = local.all_tags
}

resource "aws_s3_account_public_access_block" "this" {
  count                   = try(var.settings.s3.configure_public_access, false) ? 1 : 0
  block_public_acls       = try(var.settings.s3.block_public_acls, null)
  block_public_policy     = try(var.settings.s3.block_public_policy, null)
  ignore_public_acls      = try(var.settings.s3.ignore_public_acls, null)
  restrict_public_buckets = try(var.settings.s3.restrict_public_buckets, null)
}