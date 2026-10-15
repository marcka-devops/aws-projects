provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project   = "Marck Enterprise"
      Stack     = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}
