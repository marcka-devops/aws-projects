output "assets_bucket" {
  value = aws_s3_bucket.assets.id
}

output "website_bucket" {
  value = aws_s3_bucket.website.id
}

output "website_url" {
  value = "https://${local.www}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "Opening this name directly shows the error page (case study task 5)."
  value       = aws_cloudfront_distribution.website.domain_name
}
