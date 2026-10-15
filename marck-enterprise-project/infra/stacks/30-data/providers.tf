locals {
  default_tags = {
    Project     = "Marck Enterprise"
    Environment = "production"
    Stack       = "data"
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  region = var.primary_region
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "west"
  region = var.secondary_region
  default_tags {
    tags = local.default_tags
  }
}
