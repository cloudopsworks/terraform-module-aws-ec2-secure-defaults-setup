## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.73.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_tags"></a> [tags](#module\_tags) | cloudopsworks/tags/local | 1.0.10 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.script_log_destination_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.default_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_ebs_default_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_default_kms_key) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_ebs_snapshot_block_public_access.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_snapshot_block_public_access) | resource |
| [aws_ec2_allowed_images_settings.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_allowed_images_settings) | resource |
| [aws_ec2_image_block_public_access.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_image_block_public_access) | resource |
| [aws_ec2_instance_metadata_defaults.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_instance_metadata_defaults) | resource |
| [aws_ec2_serial_console_access.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_serial_console_access) | resource |
| [aws_kms_alias.automation_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.ebs_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.automation_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.ebs_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |
| [aws_ssm_service_setting.public_sharing_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting) | resource |
| [aws_ssm_service_setting.script_log_destination](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting) | resource |
| [aws_ssm_service_setting.script_log_destination_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting) | resource |
| [aws_vpc_block_public_access_exclusion.this_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_exclusion) | resource |
| [aws_vpc_block_public_access_exclusion.this_vpcs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_exclusion) | resource |
| [aws_vpc_block_public_access_options.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_options) | resource |
| [terraform_data.compliance_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.automation_logs_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ebs_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpcs.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | Extra tags to add to the resources | `map(string)` | `{}` | no |
| <a name="input_is_hub"></a> [is\_hub](#input\_is\_hub) | Is this a hub or spoke configuration? | `bool` | `false` | no |
| <a name="input_org"></a> [org](#input\_org) | Organization details | <pre>object({<br/>    organization_name = string<br/>    organization_unit = string<br/>    environment_type  = string<br/>    environment_name  = string<br/>  })</pre> | n/a | yes |
| <a name="input_settings"></a> [settings](#input\_settings) | (Optional) Account-level EC2, EBS, VPC, S3 and SSM secure defaults with compliance profiles (CIS, PCI DSS, AI Security on; NIST 800-53 off). Default: {} | `any` | `{}` | no |
| <a name="input_spoke_def"></a> [spoke\_def](#input\_spoke\_def) | Spoke ID Number, must be a 3 digit number | `string` | `"001"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_compliance_exceptions"></a> [compliance\_exceptions](#output\_compliance\_exceptions) | AWS Security Hub control IDs waived through settings.compliance.exceptions. |
| <a name="output_compliance_frameworks"></a> [compliance\_frameworks](#output\_compliance\_frameworks) | Compliance frameworks active for this deployment (cis, pci\_dss, ai\_security, nist\_800\_53). |
| <a name="output_ebs_kms_key_alias"></a> [ebs\_kms\_key\_alias](#output\_ebs\_kms\_key\_alias) | Alias of the module-managed default EBS KMS key, or null when the module does not create one. |
| <a name="output_ebs_kms_key_arn"></a> [ebs\_kms\_key\_arn](#output\_ebs\_kms\_key\_arn) | ARN of the module-managed default EBS KMS key, or null when the module does not create one. |
| <a name="output_ebs_kms_key_id"></a> [ebs\_kms\_key\_id](#output\_ebs\_kms\_key\_id) | ID of the module-managed default EBS KMS key, or null when the module does not create one. |
| <a name="output_ssm_automation_log_group_arn"></a> [ssm\_automation\_log\_group\_arn](#output\_ssm\_automation\_log\_group\_arn) | ARN of the CloudWatch log group receiving SSM Automation script output. |
| <a name="output_ssm_automation_log_group_name"></a> [ssm\_automation\_log\_group\_name](#output\_ssm\_automation\_log\_group\_name) | Name of the CloudWatch log group receiving SSM Automation script output. |
| <a name="output_ssm_automation_logs_kms_key_arn"></a> [ssm\_automation\_logs\_kms\_key\_arn](#output\_ssm\_automation\_logs\_kms\_key\_arn) | ARN of the KMS key encrypting the SSM Automation log group, or null when the log group uses CloudWatch-managed encryption. |
