include {
  path           = find_in_parent_folders()
  merge_strategy = "deep"
}

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
  }
}

inputs = {
  cluster_connection = dependency.cluster.outputs.cluster_connection
}
