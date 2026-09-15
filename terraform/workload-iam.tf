resource "aws_iam_role" "analytics" {
  name = "${var.project_name}-${var.environment}-analytics"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "pods.eks.amazonaws.com"
      }

      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "analytics" {
  name = "${var.project_name}-${var.environment}-analytics"
  role = aws_iam_role.analytics.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes"
        ]

        Resource = module.sqs.queue_arn
      },
      {
        Effect = "Allow"

        Action = [
          "dynamodb:PutItem"
        ]

        Resource = module.dynamodb.table_arn

      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "analytics" {
  cluster_name    = module.eks.cluster_name
  namespace       = "togglemaster"
  service_account = "analytics-sa"
  role_arn        = aws_iam_role.analytics.arn
}


resource "aws_iam_role" "evaluation" {
  name = "${var.project_name}-${var.environment}-evaluation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "pods.eks.amazonaws.com"
      }

      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "evaluation" {
  name = "${var.project_name}-${var.environment}-evaluation"
  role = aws_iam_role.evaluation.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "sqs:SendMessage"
        ]

        Resource = [
          module.sqs.queue_arn
        ]
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "evaluation" {
  cluster_name    = module.eks.cluster_name
  namespace       = "togglemaster"
  service_account = "evaluation-sa"
  role_arn        = aws_iam_role.evaluation.arn
}