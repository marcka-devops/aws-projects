locals {
  default_tags = {
    Project     = "Marck Enterprise"
    Environment = "production"
    Stack       = "storage"
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  region = var.primary_region
  default_tags {
    tags = local.default_tags
  }
}

# CloudFront only accepts certificates from us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = local.default_tags
  }
}
