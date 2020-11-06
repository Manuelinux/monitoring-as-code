## This MAY have to be tweaked to be PER customer...

resource "pagerduty_team" "Team" {
  name = var.teamName
  description = "Team ${var.teamName}"

}


resource "pagerduty_team_membership" "team" {
  count = length(var.members)
  user_id = data.pagerduty_user.users[count.index].id
  team_id = pagerduty_team.Team.id
  role = "responder"
}

resource "pagerduty_team_membership" "management" {
  count = length(var.managers)
  user_id = data.pagerduty_user.admins[count.index].id
  team_id = pagerduty_team.Team.id
  role = "manager"
}

resource "pagerduty_schedule" "schedule" {
  name = "${var.service_to_monitor} notification schedule"
  // CST
  time_zone = "America/Chicago"
  overflow = true
  layer {
    ## One week primary
    rotation_turn_length_seconds = 604800
    rotation_virtual_start = "2020-03-25T20:00:00-05:00"
    start = "2020-03-25T20:00:00-05:00"
    users = data.pagerduty_user.rotation.*.id
  }
}

/*
This is for when someone has NOT responded to an alert...
*/
resource "pagerduty_schedule" "escalation" {
  name = "${var.service_to_monitor} escalation schedule"

  // CST
  time_zone = "America/Chicago"
  overflow = true
  layer {
    ## One week primary
    rotation_turn_length_seconds = 604800
    rotation_virtual_start = "2020-03-25T20:00:00-05:00"
    start = "2020-03-25T20:00:00-05:00"
    users = concat(slice(data.pagerduty_user.rotation.*.id, 1, length(data.pagerduty_user.rotation)), list(data.pagerduty_user.rotation[0].id))
  }
}

resource "pagerduty_schedule" "managers" {
  name = "${var.service_to_monitor} manager schedule"
  // CST
  time_zone = "America/Chicago"
  overflow = true
  layer {
    ## One week primary
    rotation_turn_length_seconds = 604800
    rotation_virtual_start = "2020-03-25T20:00:00-05:00"
    start = "2020-03-25T20:00:00-05:00"
    users =  data.pagerduty_user.admins.*.id
  }
}

resource "pagerduty_escalation_policy" "default" {
  name      = "${var.service_to_monitor} Escalation Policy"
  description = "Escalation for ${var.service_to_monitor}"
  teams = [pagerduty_team.Team.id]
  num_loops = 2
  rule {
    escalation_delay_in_minutes = 30

    target {
      type = "schedule_reference"
      id   = pagerduty_schedule.schedule.id
    }
  }
  rule {
    escalation_delay_in_minutes = 20

    target {
      type = "schedule_reference"
      id   = pagerduty_schedule.escalation.id
    }
  }

  rule {
    escalation_delay_in_minutes = 20

    target {
      type = "schedule_reference"
      id   = pagerduty_schedule.managers.id
    }
  }
}

resource "pagerduty_service" "monitored_service" {
  name                    = var.service_to_monitor
  auto_resolve_timeout    = 14400
  acknowledgement_timeout = 600
  escalation_policy       = pagerduty_escalation_policy.default.id
  alert_creation          = "create_incidents"
}



data "pagerduty_vendor" "datadog" {
  name = "Datadog"
}

resource "pagerduty_service_integration" "datadog" {
  name    = data.pagerduty_vendor.datadog.name
  service = pagerduty_service.monitored_service.id
  vendor  = data.pagerduty_vendor.datadog.id
}