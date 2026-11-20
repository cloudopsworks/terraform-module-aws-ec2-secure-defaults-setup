##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

# Plan-only tests with a mocked AWS provider: run with `tofu test` (no AWS credentials needed).
mock_provider "aws" {
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_partition" { defaults = { partition = "aws", dns_suffix = "amazonaws.com" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{}" } }
  mock_data "aws_vpcs" { defaults = { ids = ["vpc-default1"] } }
  mock_resource "aws_kms_key" { defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/abc" } }
}

variables {
  org = {
    organization_name = "acme"
    organization_unit = "ops"
    environment_type  = "prod"
    environment_name  = "prd"
  }
}

run "defaults_apply_cis_pci_ai" {
  command = plan
  assert {
    condition     = output.compliance_frameworks == { cis = true, pci_dss = true, ai_security = true, nist_800_53 = false }
    error_message = "default frameworks wrong"
  }
  assert {
    condition     = aws_ec2_instance_metadata_defaults.this.http_tokens == "required"
    error_message = "imds defaults wrong"
  }
  assert {
    condition     = length(aws_s3_account_public_access_block.this) == 1 && aws_s3_account_public_access_block.this[0].block_public_acls && aws_s3_account_public_access_block.this[0].restrict_public_buckets
    error_message = "s3 bpa not enforced"
  }
  assert {
    condition     = length(aws_kms_key.ebs_key) == 1 && length(aws_ebs_default_kms_key.this) == 1
    error_message = "ai_security should create EBS CMK"
  }
  assert {
    condition     = length(aws_ec2_image_block_public_access.this) == 1 && aws_ec2_image_block_public_access.this[0].state == "block-new-sharing"
    error_message = "AMI BPA missing"
  }
  assert {
    condition     = length(aws_ec2_serial_console_access.this) == 0
    error_message = "nist-only resources present"
  }
  assert {
    condition     = length(aws_default_security_group.default_vpc) == 0 && length(aws_ec2_allowed_images_settings.this) == 0
    error_message = "opt-in resources must stay off by default"
  }
}

run "nist_enabled" {
  command = plan
  variables {
    settings = { compliance = { nist_800_53 = true } }
  }
  assert {
    condition     = length(aws_ec2_serial_console_access.this) == 1 && aws_ec2_serial_console_access.this[0].enabled == false
    error_message = "serial console not disabled"
  }
  assert {
    condition     = length(aws_kms_key.ebs_key) == 1
    error_message = "nist should create EBS CMK"
  }
}

run "all_frameworks_off_is_legacy" {
  command = plan
  variables {
    settings = { compliance = { cis = false, pci_dss = false, ai_security = false } }
  }
  assert {
    condition     = length(aws_s3_account_public_access_block.this) == 0 && length(aws_kms_key.ebs_key) == 0 && length(aws_ec2_image_block_public_access.this) == 0
    error_message = "legacy defaults changed"
  }
}

run "imds_optional_blocked" {
  command = plan
  variables {
    settings = { instance_metadata = { http_tokens = "optional" } }
  }
  expect_failures = [terraform_data.compliance_guard]
}

run "imds_optional_waived" {
  command = plan
  variables {
    settings = { instance_metadata = { http_tokens = "optional" }, compliance = { exceptions = ["ec2.8"] } }
  }
  assert {
    condition     = tolist(output.compliance_exceptions) == tolist(["EC2.8"])
    error_message = "exception not normalised"
  }
}

run "s3_public_blocked" {
  command = plan
  variables {
    settings = { s3 = { block_public_policy = false } }
  }
  expect_failures = [terraform_data.compliance_guard]
}

run "s3_public_waived_keeps_other_flags" {
  command = plan
  variables {
    settings = { compliance = { exceptions = ["S3.1"] }, s3 = { block_public_policy = false } }
  }
  assert {
    condition     = length(aws_s3_account_public_access_block.this) == 1 && aws_s3_account_public_access_block.this[0].block_public_policy == false && aws_s3_account_public_access_block.this[0].block_public_acls == true
    error_message = "waiving S3.1 must only skip the guard"
  }
}

run "s3_secondary_region_not_owner" {
  command = plan
  variables {
    settings = { s3 = { manage_account_settings = false } }
  }
  assert {
    condition     = length(aws_s3_account_public_access_block.this) == 0
    error_message = "non-owning region must not manage account S3 BPA"
  }
}

run "snapshot_block_new_sharing_rejected" {
  command = plan
  variables {
    settings = { ebs = { snapshot_block_public_access = "block-new-sharing" } }
  }
  expect_failures = [terraform_data.compliance_guard]
}

run "snapshot_waived_via_alias" {
  command = plan
  variables {
    settings = { ebs = { snapshot_block_public_access = "unblocked" }, compliance = { exceptions = ["EC2.182"] } }
  }
  assert {
    condition     = tolist(output.compliance_exceptions) == tolist(["EC2.1"])
    error_message = "EC2.182 alias not mapped to EC2.1"
  }
}

run "unknown_exception_rejected" {
  command = plan
  variables {
    settings = { compliance = { exceptions = ["S3-1"] } }
  }
  expect_failures = [terraform_data.compliance_guard]
}

run "allowed_images_enabled_without_criteria_rejected" {
  command = plan
  variables {
    settings = { ec2 = { allowed_images = { state = "enabled" } } }
  }
  expect_failures = [terraform_data.compliance_guard]
}

run "null_flags_fall_back_to_defaults" {
  command = plan
  variables {
    settings = { compliance = { cis = null, exceptions = null }, ebs = { encryption_by_default = null } }
  }
  assert {
    condition     = output.compliance_frameworks.cis == true && aws_ebs_encryption_by_default.this.enabled == true
    error_message = "null values must fall back to defaults"
  }
}

run "kms_rotation_blocked" {
  command = plan
  variables {
    settings = { ebs = { default_kms_key = { enable_key_rotation = false } } }
  }
  expect_failures = [terraform_data.compliance_guard]
}

run "snapshot_unblocked_blocked" {
  command = plan
  variables {
    settings = { ebs = { snapshot_block_public_access = "unblocked" } }
  }
  expect_failures = [terraform_data.compliance_guard]
}

run "vpc_exclusions_and_default_sg_and_allowed_amis" {
  command = plan
  variables {
    settings = {
      vpc = {
        configure_public_access             = true
        block_public_access                 = "block-ingress"
        restrict_default_vpc_security_group = true
        exclusions = [
          { mode = "allow-egress", vpc_id = "vpc-1" },
          { mode = "allow-bidirectional", vpc_id = "vpc-2", subnet_id = "subnet-2" },
        ]
      }
      ec2 = {
        allowed_images = {
          state    = "audit-mode"
          criteria = [{ image_providers = ["amazon"], maximum_days_since_created = 365 }]
        }
      }
    }
  }
  assert {
    condition     = keys(aws_vpc_block_public_access_exclusion.this_vpcs) == ["vpc-1"] && keys(aws_vpc_block_public_access_exclusion.this_subnets) == ["subnet-2"]
    error_message = "exclusion split wrong"
  }
  assert {
    condition     = aws_vpc_block_public_access_exclusion.this_subnets["subnet-2"].vpc_id == null
    error_message = "subnet exclusion must not set vpc_id"
  }
  assert {
    condition     = length(aws_default_security_group.default_vpc) == 1 && length(aws_ec2_allowed_images_settings.this) == 1
    error_message = "default sg / allowed images missing"
  }
}

run "allowed_images_mixed_criteria_keys" {
  command = plan
  variables {
    settings = {
      ec2 = {
        allowed_images = {
          state = "enabled"
          criteria = [
            { image_providers = ["amazon"] },
            { image_names = ["al2023-ami-*"], maximum_days_since_created = 365 },
          ]
        }
      }
    }
  }
  assert {
    condition     = length(aws_ec2_allowed_images_settings.this) == 1 && length(aws_ec2_allowed_images_settings.this[0].image_criterion) == 2
    error_message = "mixed criteria entries must plan"
  }
}
