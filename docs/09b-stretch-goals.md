# Stretch goals — only after all 34 checklist items pass

Quick notes on how each stretch goal builds on what's already here. Don't start any of these until `docs/CHECKLIST.md` is fully ticked — a broken stretch goal costs more than a missing one.

| Stretch | Starting point in this repo |
|---|---|
| HTTPS on a real domain (ACM) | Requires owning a domain. Add `aws_acm_certificate` (DNS-validated) + a Route 53 hosted zone, attach the cert to `aws_lb_listener` (new 443 listener + redirect 80→443) and to the CloudFront distribution's `viewer_certificate`. |
| Auto-scaling on ECS | Add `aws_appautoscaling_target` + `aws_appautoscaling_policy` (target tracking on `ECSServiceAverageCPUUtilization`, e.g. 60%) to `ecs.tf`. Demonstrate with `scripts/load-test.sh` at higher concurrency. |
| Cognito login | New `aws_cognito_user_pool` + `aws_cognito_user_pool_client`; frontend adds a login step before calling `/api/*`; API would need a JWT-validation filter — this is the one stretch goal that touches real app code, budget real time for it. |
| Blue/green with rollback | Switch the ECS service's `deployment_controller` to `CODE_DEPLOY`, add an `aws_codedeploy_app` + `aws_codedeploy_deployment_group`, a second ("green") target group, and CloudWatch-alarm-triggered automatic rollback. |
| Scheduled nightly shutdown/morning start-up | An `aws_scheduler_schedule` (or two `aws_cloudwatch_event_rule`s) invoking a tiny Lambda that calls `ecs update-service --desired-count 0` at night and `--desired-count 1` in the morning. Note: this doesn't touch the ALB or NAT instance costs, only Fargate's. |
| RDS → DynamoDB branch | A genuinely separate exercise: new `aws_dynamodb_table`, rewrite the repository layer to use the AWS SDK instead of Spring Data JPA, drop `schema.sql`. Do this in a git branch, not on the graded stack — the brief wants a write-up of what changed, not a working parallel deployment.
