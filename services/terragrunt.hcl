remote_state {
  backend = "local"
  config  = {}
}

dependency "cluster" {
  config_path = "../cluster"

  mock_outputs = {
    cluster_connection = {
      api_server_url  = ""
      kube_admin_user = ""
      client_cert     = ""
      client_key      = ""
      ca_crt          = ""
    }
    kube_config_yaml = ""
  }
}

dependencies {
  paths = ["../metal", "../cluster"]
}

inputs = {
  cluster_connection = dependency.cluster.outputs.cluster_connection
  kube_config_yaml = dependency.cluster.outputs.kube_config_yaml
}
