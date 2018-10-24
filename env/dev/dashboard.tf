/**
 * This module creates a CloudWatch dashboard for your scheduled task.
 */

resource "aws_cloudwatch_dashboard" "cloudwatch_dashboard" {
  dashboard_name = "${local.namespace}-fargate-scheduled-task"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 9,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/Events",
            "FailedInvocations",
            "RuleName",
            "${local.namespace}",
            { "color": "#d62728", "period": 1, "stat": "Maximum" }
          ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "Failed Invocations",
        "period": 300
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 9,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/Events",
            "Invocations",
            "RuleName",
            "${local.namespace}",
            { "period": 1, "stat": "Maximum", "color": "#2ca02c" }
          ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "title": "Invocations",
        "period": 300
      }
    }
  ]
}
EOF
}
