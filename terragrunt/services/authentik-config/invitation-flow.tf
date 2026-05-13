# Invitation-based enrollment flow.
#
# Lets you mint single-use invitation URLs from the Authentik UI (Directory →
# Invitations → Create) that take the invitee through a short form to set
# their own username, name and password. No invitation token = no enrollment;
# the flow refuses to continue without one, so this isn't a public sign-up.
#
# Workflow once applied:
#   1. UI → Directory → Invitations → Create. Pick "enrollment" as the flow,
#      add the invitee's email if you want Authentik to email the link, or
#      copy the resulting URL by hand.
#   2. Invitee opens https://auth.<domain>/if/flow/enrollment/?itoken=<uuid>
#      and walks through username + name + password.
#   3. Authentik creates the user, logs them in. Add them to groups manually
#      (or pre-create them in env.hcl `managed_users` if known upfront).

resource "authentik_stage_prompt_field" "enroll_username" {
  name        = "enroll-username"
  field_key   = "username"
  label       = "Username"
  type        = "username"
  required    = true
  placeholder = "username"
  order       = 100
}

resource "authentik_stage_prompt_field" "enroll_name" {
  name        = "enroll-name"
  field_key   = "name"
  label       = "Display name"
  type        = "text"
  required    = true
  placeholder = "Your name"
  order       = 200
}

resource "authentik_stage_prompt_field" "enroll_email" {
  name        = "enroll-email"
  field_key   = "email"
  label       = "Email"
  type        = "email"
  required    = true
  placeholder = "you@example.com"
  order       = 300
}

resource "authentik_stage_prompt_field" "enroll_password" {
  name      = "enroll-password"
  field_key = "password"
  label     = "Password"
  type      = "password"
  required  = true
  order     = 400
}

resource "authentik_stage_prompt_field" "enroll_password_repeat" {
  name      = "enroll-password-repeat"
  field_key = "password_repeat"
  label     = "Repeat password"
  type      = "password"
  required  = true
  order     = 500
}

# Validates the `itoken` query param against issued invitations. Setting
# `continue_flow_without_invitation = false` is what makes the flow closed —
# no token, no enrollment.
resource "authentik_stage_invitation" "enrollment" {
  name                             = "enrollment-invitation"
  continue_flow_without_invitation = false
}

resource "authentik_stage_prompt" "enrollment" {
  name = "enrollment-prompt"
  fields = [
    authentik_stage_prompt_field.enroll_username.id,
    authentik_stage_prompt_field.enroll_name.id,
    authentik_stage_prompt_field.enroll_email.id,
    authentik_stage_prompt_field.enroll_password.id,
    authentik_stage_prompt_field.enroll_password_repeat.id,
  ]
}

resource "authentik_stage_user_write" "enrollment" {
  name                     = "enrollment-user-write"
  create_users_as_inactive = false
  user_creation_mode       = "always_create"
  # `internal` lets the user log into the Authentik UI itself. The default
  # otherwise is `external`, which is for outpost-only users (LDAP/SCIM
  # consumers) and trips the "Interface can only be accessed by internal
  # users" denial on first login.
  user_type = "internal"
  # Keep invited users in their own path so they're easy to distinguish from
  # TF-declared users in users/managed.
  user_path_template = "users/invited"
}

resource "authentik_stage_user_login" "enrollment" {
  name = "enrollment-user-login"
}

resource "authentik_flow" "enrollment" {
  name           = "Enrollment"
  title          = "Welcome — set up your account"
  slug           = "enrollment"
  designation    = "enrollment"
  authentication = "none"

  depends_on = [terraform_data.authentik_gate]
}

# Order matters: invitation token check first (gate), then collect form data,
# then write the user, then log them in.
resource "authentik_flow_stage_binding" "enrollment_invitation" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_invitation.enrollment.id
  order  = 10
}

resource "authentik_flow_stage_binding" "enrollment_prompt" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_prompt.enrollment.id
  order  = 20
}

resource "authentik_flow_stage_binding" "enrollment_write" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_user_write.enrollment.id
  order  = 30
}

resource "authentik_flow_stage_binding" "enrollment_login" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_user_login.enrollment.id
  order  = 40
}
