resource "auth0_client" "argocd" {
  name = "argocd"
  callbacks = ["https://argocd.${var.domain}/auth/callback"]
  initiate_login_uri = "https://argocd.${var.domain}/login"
  app_type = "regular_web"
  oidc_conformant = true

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_rule" "argocd" {
  name = "empty-rule"
  enabled = true
  script = <<EOF
    function (user, context, callback) {
    var namespace = 'https://argocd.${var.domain}/claims/';
    context.idToken[namespace + "groups"] = user.groups;
    callback(null, user, context);
  }
  EOF
}
