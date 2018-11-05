/**
 * Elastic Container Service (ecs)
 * This component is required to create the Fargate ECS components. It will create a Fargate cluster
 * based on the application name and environment. It will create a "Task Definition", which is required
 * to run a Docker container, https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html.
 * It also creates a role with the correct permissions. And lastly, ensures that logs are captured in CloudWatch.
 *
 * When building for the first time, it will install the "hello-world" () image. 
 * The Fargate CLI can be used to deploy new application image on top of this infrastructure.
 */

resource "aws_ecs_cluster" "app" {
  name = "${local.namespace}"
}

# name of the container in the task definition
variable "container_name" {
  default = "app"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.namespace}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"

  # defined in role.tf
  task_role_arn = "${aws_iam_role.app_role.arn}"

  container_definitions = <<DEFINITION
[
  {
    "name": "${var.container_name}",
    "image": "hello-world",
    "essential": true,
    "portMappings": [],
    "environment": [],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${local.log_group}",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "fargate"
      }
    }
  }
]
DEFINITION
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "${local.namespace}-ecs"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

# allow task execution role to be assumed by ecs
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# allow task execution role to work with ecr and cw logs
resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/CWE_IAM_role.html
resource "aws_iam_role" "cloudwatch_events_role" {
  name               = "${local.namespace}-events"
  assume_role_policy = "${data.aws_iam_policy_document.events_assume_role_policy.json}"
}

# allow events role to be assumed by events service 
data "aws_iam_policy_document" "events_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

# allow events role to run ecs tasks
data "aws_iam_policy_document" "events_ecs" {
  statement {
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = ["arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:task-definition/${aws_ecs_task_definition.app.family}:*"]

    condition {
      test     = "StringLike"
      variable = "ecs:cluster"
      values   = ["${aws_ecs_cluster.app.arn}"]
    }
  }
}

resource "aws_iam_role_policy" "events_ecs" {
  name   = "${var.app}-${var.environment}-events-ecs"
  role   = "${aws_iam_role.cloudwatch_events_role.id}"
  policy = "${data.aws_iam_policy_document.events_ecs.json}"
}

# allow events role to pass role to task execution role and app role
data "aws_iam_policy_document" "passrole" {
  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]

    resources = [
      "${aws_iam_role.app_role.arn}",
      "${aws_iam_role.ecsTaskExecutionRole.arn}",
    ]
  }
}

resource "aws_iam_role_policy" "events_ecs_passrole" {
  name   = "${var.app}-${var.environment}-events-ecs-passrole"
  role   = "${aws_iam_role.cloudwatch_events_role.id}"
  policy = "${data.aws_iam_policy_document.passrole.json}"
}

resource "aws_cloudwatch_log_group" "logs" {
  name              = "${local.log_group}"
  retention_in_days = "14"
  tags              = "${var.tags}"
}

# The shedule on which to run the fargate task. Follows the CloudWatch Event Schedule Expression format: https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html
variable "schedule_expression" {}

resource "aws_cloudwatch_event_rule" "scheduled_task" {
  name                = "${local.namespace}"
  description         = "Runs fargate task ${local.namespace}: ${var.schedule_expression}"
  schedule_expression = "${var.schedule_expression}"
}

resource "aws_cloudwatch_event_target" "scheduled_task" {
  rule      = "${aws_cloudwatch_event_rule.scheduled_task.name}"
  target_id = "${local.namespace}"
  arn       = "${aws_ecs_cluster.app.arn}"
  role_arn  = "${aws_iam_role.cloudwatch_events_role.arn}"
  input     = "{}"

  ecs_target = {
    task_count          = 1
    task_definition_arn = "${aws_ecs_task_definition.app.arn}"
    launch_type         = "FARGATE"
    platform_version    = "LATEST"

    network_configuration {
      assign_public_ip = false
      security_groups  = ["${aws_security_group.nsg_task.id}"]
      subnets          = ["${split(",", var.private_subnets)}"]
    }
  }

  # allow the task definition to be managed by external ci/cd system
  lifecycle = {
    ignore_changes = ["ecs_target.0.task_definition_arn"]
  }
}
