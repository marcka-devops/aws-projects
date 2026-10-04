resource "aws_imagebuilder_component" "codedeploy" {
  name     = "${var.name_prefix}-codedeploy-agent"
  platform = "Linux"
  version  = "1.0.0"
  data     = file("${path.module}/files/imagebuilder/codedeploy.yml")
}

resource "aws_imagebuilder_image_recipe" "web" {
  name         = "${var.name_prefix}-web"
  version      = "1.0.0"
  parent_image = "arn:aws:imagebuilder:${var.primary_region}:aws:image/amazon-linux-2023-x86/x.x.x"

  component {
    component_arn = aws_imagebuilder_component.codedeploy.arn
  }

  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 30
      volume_type = "gp3"
      encrypted   = true
    }
  }

  block_device_mapping {
    device_name = "/dev/sdf"

    ebs {
      volume_size = 50
      volume_type = "gp3"
      encrypted   = true
    }
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "web" {
  name                          = "${var.name_prefix}-web"
  instance_profile_name         = aws_iam_instance_profile.imagebuilder.name
  instance_types                = [var.web_instance_type]
  subnet_id                     = aws_subnet.production["web_a"].id
  security_group_ids            = [aws_security_group.imagebuilder.id]
  terminate_instance_on_failure = true
}

resource "aws_imagebuilder_distribution_configuration" "web" {
  name = "${var.name_prefix}-web"

  distribution {
    region = var.primary_region

    ami_distribution_configuration {
      name = "${var.name_prefix}-web-{{ imagebuilder:buildDate }}"
    }
  }

  distribution {
    region = var.secondary_region

    ami_distribution_configuration {
      name = "${var.name_prefix}-web-{{ imagebuilder:buildDate }}"
    }
  }
}

resource "aws_imagebuilder_image_pipeline" "web" {
  name                             = "${var.name_prefix}-web"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.web.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.web.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.web.arn
}
