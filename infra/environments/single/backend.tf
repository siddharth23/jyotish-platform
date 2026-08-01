# Remote state lives in Hetzner Object Storage (S3-compatible), not on a laptop and not in
# this repo. The bucket isn't managed by Terraform here because Hetzner Object Storage buckets
# aren't yet supported by the hcloud provider — create it once by hand:
#
#   Hetzner Cloud Console -> Object Storage -> Create Bucket
#     name:     jyotish-tfstate
#     location: fsn1
#   Then generate an access key/secret for that bucket (Object Storage -> Access Keys).
#
# Initialise with the access key as backend config, not a committed file:
#
#   terraform init \
#     -backend-config="access_key=$HETZNER_OBJECT_STORAGE_ACCESS_KEY" \
#     -backend-config="secret_key=$HETZNER_OBJECT_STORAGE_SECRET_KEY"

terraform {
  backend "s3" {
    bucket                      = "jyotish-tfstate"
    key                         = "single/terraform.tfstate"
    region                      = "fsn1"
    endpoints                   = { s3 = "https://fsn1.your-objectstorage.com" }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    force_path_style            = true
  }
}
