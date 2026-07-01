locals {
  sops_system_namespace = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = "sops-system" }
  }

  sops_operator_age_keys_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "age-keys", namespace = "sops-system" }
    data       = { "keys.txt" = base64encode(var.argocd_age_key) }
  }

  sops_manifests = [
    { name = "ns-sops-system", contents = yamlencode(local.sops_system_namespace) },
    { name = "sops-operator-age-keys-secret", contents = yamlencode(local.sops_operator_age_keys_secret) },
  ]
}
