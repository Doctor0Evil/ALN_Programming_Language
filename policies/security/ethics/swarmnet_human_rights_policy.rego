package swarmnet.security.ethics

# Default rule: deny if any ethical or safety constraint fails
default allow = false

# --- Human Rights and Ethical Safeguards ---

human_rights_principles = {
  "privacy": true,
  "freedom_from_harm": true,
  "user_data_control": true,
  "transparency": true,
  "consent": true
}

# --- Security Requirements ---

encryption_compliant if {
  input.network.encryption == "enabled"
  input.network.protocol == "TLS1.3"
}

consent_mode_enabled if {
  all device in input.devices {
    device.access_mode == "consent_required"
  }
}

no_hidden_tracking if {
  all device in input.devices {
    device.tracking == false
  }
}

no_hidden_telemetry if {
  all device in input.devices {
    not device.hidden_telemetry
  }
}

# --- Deny Rules for Violations ---

deny["unencrypted_traffic_not_allowed"] if {
  not encryption_compliant
}

deny["consent_not_enforced"] if {
  not consent_mode_enabled
}

deny["tracking_detected"] if {
  not no_hidden_tracking
}

deny["telemetry_hidden_detected"] if {
  not no_hidden_telemetry
}

# --- Allow Rule ---

allow if {
  encryption_compliant
  consent_mode_enabled
  no_hidden_tracking
  no_hidden_telemetry
  not deny[_]
}
