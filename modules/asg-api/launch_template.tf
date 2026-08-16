# EC2の起動設定(AMI・インスタンスタイプ・ユーザデータ・SG等)を定義する。
# 実際のEC2インスタンスは、このLaunch Templateを元にAuto Scaling Group(main.tf)が起動・管理する。
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = var.ami_ssm_parameter_name
}

resource "aws_launch_template" "api" {
  name          = "${var.name}-api-lt"
  image_id      = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = var.instance_type
  user_data     = base64encode(var.user_data)

  iam_instance_profile {
    name = aws_iam_instance_profile.api.name
  }

  # IMDSv2を必須化する
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.api.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-api" })
  }

  tags = var.tags
}
