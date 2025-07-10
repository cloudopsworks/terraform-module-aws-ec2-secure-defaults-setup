##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

## Settings for the module - YAML format
# settings:
#   ebs:
#     encryption_by_default: true
#     snapshot_block_public_access: block-all-sharing | block-new-sharing | unblocke
#     default_kms_key:
#       enabled: true | false         # deafults to false
#       deletion_window_in_days: 30   # defaults to 30
#       enable_key_rotation: true     # defaults to true
#       rotation_period_in_days: 365  # defaults to 365
#       is_enabled: true              # defaults to true
#   instance_metadata:
#     http_endpoint: "enabled" |  "disabled" | "no-preference" # default is "enabled"
#     http_tokens: "required" | "optional" | "no-preference"   # default is "required"
#     http_put_response_hop_limit: 1 to 64               # default is null implies "-1" (no limit)
#     tags: "enabled" |  "disabled" | "no-preference"          # default is null implies "no-preference"
#   vpc:
#     block_public_access: "block-bidirectional" | "block-ingress" | "off" # default is "off"
#     exclusions:
#       - mode: "allow-ingress" | "allow-bidirectional" # Required: Mode of exclusion
#         vpc_id: "vpc-12345678" # Optional: VPC ID to exclude from public access options
#         subnet_id: "subnet-12345678" # Optional: Subnet ID to exclude
variable "settings" {
  description = "Settings for the EC2 instance metadata defaults."
  type        = any
  default     = {}
}