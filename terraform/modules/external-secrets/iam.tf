data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        var.oidc_provider_arn
      ]
    }

    condition {
      test = "StringEquals"

      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test = "StringEquals"

      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${var.namespace}:${var.service_account_name}"
      ]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name = "${var.project_name}-${var.environment}-external-secrets-role"

  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = var.secret_arns
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "${var.project_name}-${var.environment}-external-secrets-policy"
  role = aws_iam_role.external_secrets.id

  policy = data.aws_iam_policy_document.external_secrets.json
}