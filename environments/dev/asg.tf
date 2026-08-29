# [Terraform構文] `data`ブロック: 新しいリソースを作るのではなく、既存の情報を「参照」するための構文。
# ここではAWSが管理しているSSM Parameter Storeの値を読み取り、常に最新のAmazon Linux 2023
# AMI IDを取得している(AMI IDを直接ハードコードすると、新しいAMIが出るたびに書き換えが必要になるため)。
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

  # [セキュリティ] IMDSv2を必須化する。EC2にはIAMロールの認証情報等を取得できる
  # メタデータサービス(169.254.169.254)があるが、旧方式(IMDSv1)はSSRF攻撃で
  # その認証情報を盗まれるリスクがある。IMDSv2はトークン必須化でこれを防ぐ。
  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type = "gp3"
      # [セキュリティ] ルートボリューム(OSディスク)を暗号化する。
      encrypted = true
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
  name = "${local.name_prefix}-api-asg"
  # [Terraform構文] `[*]`はsplat式。リストの各要素から`.id`だけを取り出して
  # 配列にする(`aws_subnet.private` = privateサブネット2つのリスト → IDだけの配列に変換)。
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

  # [Terraform構文] dynamic block: Auto Scaling Groupの`tag`は(他のリソースの`tags = {...}`と違い)
  # 1つ1つ`tag { key = ... value = ... }`というブロックとして書く仕様。
  # タグの数だけこのブロックを手書きするのは大変なので、`dynamic`でmap(common_tags)を
  # 展開してブロックを自動生成している。`for_each`で回している最中の1個分の要素が`tag`という名前で使える。
  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${local.name_prefix}-api" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # [問題点] depends_onがaws_nat_gateway.thisだけだと、「NAT Gatewayという“モノ”ができたこと」しか
  # 保証されない。EC2が実際にインターネットへ出られるかどうかを決めるのは、プライベートサブネットの
  # ルートテーブルがNAT Gatewayへの経路を持ち、かつそのサブネットに紐付いていること
  # (aws_route_table_association.private)であり、これは別リソースなので依存関係グラフ上は
  # 保証されていなかった(NAT Gateway完成と同時にEC2起動が始まり得る)。
  # [修正] aws_route_table_association.privateもdepends_onに加え、プライベートサブネットの経路が
  # 実際に確立してからEC2(userdata)が動き出すことを明示的に保証する。
  depends_on = [aws_nat_gateway.this, aws_route_table_association.private]
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
