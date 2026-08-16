data "aws_ssm_parameter" "amazon_linux_2023" {
  name = var.ami_ssm_parameter_name
}

# APIサーバ用セキュリティグループ: ALBからの80番のみ許可し、インターネットからの直接アクセスは拒否する
resource "aws_security_group" "api" {
  name        = "${var.name}-api-sg"
  description = "API server security group: allow HTTP(80) from ALB only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-api-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.api.id
  description                  = "Allow HTTP(80) from ALB security group only"
  referenced_security_group_id = var.alb_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# ソフトウェアインストール等のためのアウトバウンド通信(NAT Gateway経由)を許可する
resource "aws_vpc_security_group_egress_rule" "http_outbound" {
  security_group_id = aws_security_group.api.id
  description       = "Allow outbound HTTP(80) for package installation"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "https_outbound" {
  security_group_id = aws_security_group.api.id
  description       = "Allow outbound HTTPS(443) for package installation"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# SSH(22番)による直接ログインは許可しない(SG未定義=ALB以外からのインバウンドは全拒否)。
# 運用時のログインが必要な場合は、以下のSSM Session Manager用ロールを利用する。

resource "aws_iam_role" "api" {
  name = "${var.name}-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# SSHポートを開放せずに運用アクセス(Session Manager)を可能にするため付与する
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "api" {
  name = "${var.name}-api-profile"
  role = aws_iam_role.api.name

  tags = var.tags
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

resource "aws_autoscaling_group" "api" {
  name                = "${var.name}-api-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.api.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-api" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# CPU使用率70%(デフォルト)を境に2〜4台の範囲でスケールアウト/インする
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.api.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}
