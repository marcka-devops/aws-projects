provider "aws" {
  region = var.primary_region
  default_tags {
    tags = {
      Project     = "Marck Enterprise"
      Environment = "production"
      Stack       = "security"
      ManagedBy   = "terraform"
    }
  }
}
