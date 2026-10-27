data "aws_iam_policy_document" "loki_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:observability:loki"]
    }
  }
}

resource "aws_iam_role" "loki" {
  name               = "${var.project_name}-${var.environment}-loki"
  assume_role_policy = data.aws_iam_policy_document.loki_assume_role.json
  tags               = local.loki_tags
}

data "aws_iam_policy_document" "loki_s3" {
  statement {
    sid       = "ListLokiBuckets"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [for bucket in aws_s3_bucket.loki : bucket.arn]
  }

  statement {
    sid       = "ManageLokiObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [for bucket in aws_s3_bucket.loki : "${bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "loki_s3" {
  name   = "${var.project_name}-${var.environment}-loki-s3"
  policy = data.aws_iam_policy_document.loki_s3.json
  tags   = local.loki_tags
}

resource "aws_iam_role_policy_attachment" "loki_s3" {
  role       = aws_iam_role.loki.name
  policy_arn = aws_iam_policy.loki_s3.arn
}
