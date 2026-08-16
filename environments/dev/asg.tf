data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# EC2の起動設定(AMI・インスタンスタイプ・ユーザデータ等)
resource "aws_launch_template" "api" {
  name                   = "${local.name_prefix}-api-lt"
  image_id               = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type          = var.api_instance_type
  user_data              = base64encode(file("${path.module}/templates/userdata.sh"))
  vpc_security_group_ids = [aws_security_group.api.id]

  # IMDSv2を必須化する
  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-api" })
  }

  tags = local.common_tags
}

# Auto Scaling Group: 通常min_size台、CPU負荷に応じて最大max_size台まで自動増減する
resource "aws_autoscaling_group" "api" {
  name                = "${local.name_prefix}-api-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.api.arn]

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.api.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${local.name_prefix}-api" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # NAT Gateway経由の経路が確立してからEC2を起動する
  depends_on = [aws_nat_gateway.this]
}

# CPU使用率がしきい値を超えたらスケールアウト、下回れば自動でスケールインする
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${local.name_prefix}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.api.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.asg_cpu_target_value
  }
}
