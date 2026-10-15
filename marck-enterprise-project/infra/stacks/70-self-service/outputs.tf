output "portfolio_id" {
  value = aws_servicecatalog_portfolio.developers.id
}

output "product_id" {
  value = aws_servicecatalog_product.test_stack.id
}

output "template_url" {
  value = "https://${aws_s3_bucket.catalog.bucket_regional_domain_name}/${aws_s3_object.template.key}"
}
