# Bucket, região e conta são fornecidos no init; cada ambiente possui sua key.
terraform {
  backend "s3" {}
}
