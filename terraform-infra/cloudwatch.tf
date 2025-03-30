/**
- create your own log group
- create log metric filter (this is what defines the pattern)
- create cloudwatch metric alarm
- create sns topic
- create sns topic subscription
*/
// event bridge logs
// maybe use the module instead
// https://github.com/terraform-aws-modules/terraform-aws-cloudwatch
# resource "aws_cloudwatch_log_group" "event_bridge_log_group" {
#   name = "/aws/events/event-bridge-log-group" // for some reason, for the log
#   // group to be picked up by event bridge - it needs to start with /aws/events
#   retention_in_days = 1
# }

module "log_group" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/log-group"
  version = "~> 3.0"

  name              = "/aws/events/eventbridge-group"
  retention_in_days = 120
}
