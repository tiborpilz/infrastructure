locals {
  gateway_system_namespace = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = "gateway-system" }
  }

  gateway_pre_manifests = [
    { name = "ns-gateway-system", contents = yamlencode(local.gateway_system_namespace) },
    { name = "gateway-api-crds", contents = data.http.gateway_api_crds.response_body },
  ]

  # The GatewayClass, Gateway and redirect route live in
  # applications/operators/cilium-gateway and are synced by ArgoCD.
  gateway_post_manifests = []
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/experimental-install.yaml"
}
