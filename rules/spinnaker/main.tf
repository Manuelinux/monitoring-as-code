
locals {
  seconds_in_nanoseconds = "1000000000"
}



resource "datadog_monitor" "request_latency" {
  count = length(var.services)
  type = "metric alert"
  name = "Outgoing request latency for ${var.services[count.index]}"
  message = <<EOF
{{#is_alert}}
High request latency detected for ${var.services[count.index]} for {{customer}}.  Determine if slowness is caused by downstream, external services or by the affected service itself, by looking at other metrics.
{{/is_alert}}
{{#is_recovery}}
Latency has recovered on ${var.services[count.index]} for {{customer}}.
{{/is_recovery}}
Notify: ${var.slack_channel}
EOF

  // `sum(rate($service:controller:invocations__totalTime_total[1m])) by (controller, method) / sum(rate($service:controller:invocations__count_total[1m])) by (controller, method)`
  // This is the delta between the one devided by the sum of invocations... I'm NOT sure that the other shouldn't be a dt as well...
  query = "avg(last_5m):per_minute(avg:spinnaker.${var.services[count.index]}_okhttp_requests_totalTime_total{env:prod} by {customer,requesthost,instance}) / ${local.seconds_in_nanoseconds} / per_minute(avg:spinnaker.${var.services[count.index]}_okhttp_requests_count_total{env:prod} by {customer,requesthost,instance}) > 15"

  thresholds = {
    ok = 5
    warning = 10
    warning_recovery = 7
    critical = 15
    critical_recovery = 12
  }

  notify_no_data = false
  renotify_interval = 60

  notify_audit = false
  timeout_h = 1
  include_tags = false


  # ignore any changes in silenced value; using silenced is deprecated in favor of downtimes
  lifecycle {
    ignore_changes = [
      silenced]
  }

}


resource "datadog_monitor" "jvm_memory_usage" {
  count = length(var.services)
  name = "${var.services[count.index]} JVM Memory Usage"
  type = "metric alert"
  query = "avg(last_5m):avg:spinnaker.${var.services[count.index]}_jvm_memory_used{memtype:heap} by {env,customer,instance} <= 0"
  message = <<EOF
{{#is_no_data}}
{{customer.name}} ${var.services[count.index]} from env {{env.name}} is down for the last 5m, please check logs.
{{/is_no_data}}
{{#is_recovery}}
{{customer.name}} ${var.services[count.index]} from env {{env.name}} is now running successfully.
{{/is_recovery}}
EOF

  notify_audit = false
  locked = false
  timeout_h = 0
  new_host_delay = 300
  require_full_window = false
  notify_no_data = true
  renotify_interval = 60
  no_data_timeframe = 5
  include_tags = true
  thresholds = {
    critical = 0
  }
  lifecycle {
    ignore_changes = [
      silenced]
  }

}

resource "datadog_monitor" "kubectl_latency" {
  count = length(var.services_k8s)
  type = "metric alert"
  name = "Kubernetes kubectl latency for ${element(var.services_k8s, count.index)}"
  message = <<EOF
{{#is_alert}}
High kubectl latency detected for ${var.services_k8s[count.index]} for {{customer}} {{env}}.  Determine if slowness is caused by downstream, external services or by the affected service itself, by looking at other metrics.
{{/is_alert}}
{{#is_recovery}}
Latency has recovered on ${var.services_k8s[count.index]} for {{customer}} {{env}}.
{{/is_recovery}}
Notify: ${var.slack_channel}
EOF

  query = "avg(last_5m):per_minute(sum:spinnaker.${var.services_k8s[count.index]}_kubernetes_api_totalTime_total{success:true} by {action,env,customer}) / ${local.seconds_in_nanoseconds} / per_minute(sum:spinnaker.${var.services_k8s[count.index]}_kubernetes_api_count_total{success:true} by {action,env,customer}) > 5"

  thresholds = {
    warning = 3
    critical = 5
  }

  notify_no_data = false
  renotify_interval = 60

  notify_audit = false
  timeout_h = 60
  include_tags = false

  # ignore any changes in silenced value; using silenced is deprecated in favor of downtimes
  lifecycle {
    ignore_changes = [
      silenced]
  }

}

resource "datadog_monitor" "failed_request" {
  count = length(var.services)
  type = "metric alert"
  name = "AWS Failed request from ${var.services[count.index]}"
  message = <<EOF
{{#is_alert}}
AWS failed requests from ${var.services[count.index]} for {{customer}}.  Indicates the amount of failed requests from Spinnaker to AWS infrastructure.
{{/is_alert}}
{{#is_recovery}}
AWS requests has recovered from ${var.services[count.index]} for {{customer}}.
{{/is_recovery}}
Notify: ${var.slack_channel}
EOF

  query = "avg(last_5m):per_minute(sum:spinnaker.${var.services[count.index]}_aws_request_requestCount_total{error:true} by {awserrorcode,requesttype,customer,env}) > 100"

  thresholds = {
    critical= 100
  }

  notify_no_data = false
  renotify_interval = 60

  notify_audit = false
  timeout_h = 1
  include_tags = false


  # ignore any changes in silenced value; using silenced is deprecated in favor of downtimes
  lifecycle {
    ignore_changes = [
      silenced]
  }

}

resource "datadog_monitor" "http_check"{
  name               = "Service {{url}} is down for {{customer.name}}"
  type               = "service check"
  query              = "\"http.can_connect\".over(\"env:prod\").by(\"customer\",\"url\").last(4).count_by_status()"
  message            = <<EOF
Service situation detected for {{customer}} on {{url}}.
{{#is_alert}}
@pagerduty-DataDog_Managed_Customers
{{/is_alert}}

{{#is_recovery}}
Service {{url}} has recovered  for {{customer}}.
{{/is_recovery}}

@slack-DataDog_Managed-managed-alerts"
EOF

  notify_audit          = false
  locked                = false
  timeout_h             = 0
  new_host_delay        = 300
  require_full_window   = false
  notify_no_data        = true
  renotify_interval     = 60
  no_data_timeframe     = 5
  include_tags          = true
  thresholds = {
    warning = 1
    critical = 3
  }

  lifecycle {
    ignore_changes = [silenced]
  }

}