data "pagerduty_user" "admins" {
  count = length(var.managers)
  email = var.managers[count.index]
}

data "pagerduty_user" "users" {
  count = length(var.members)
  email = var.members[count.index]
}
data "pagerduty_user" "rotation" {
  count = length(var.on_call_rotation)
  email = var.on_call_rotation[count.index]
}
