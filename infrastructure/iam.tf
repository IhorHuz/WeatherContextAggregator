data "aws_iam_policy_document" "cloudwatch_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudwatch_role" {
  name               = "ips-cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role.json

  tags = {
    Name = "ips-cloudwatch-role"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloudwatch_profile" {
  name = "ips-cloudwatch-profile"
  role = aws_iam_role.cloudwatch_role.name
}

resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "ips-nginx-access"
  retention_in_days = 30

  tags = {
    Name = "ips-nginx-access-logs"
  }
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "ips-nginx-error"
  retention_in_days = 30

  tags = {
    Name = "ips-nginx-error-logs"
  }
}
