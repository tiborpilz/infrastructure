remote_state {
  backend = "local"
  config = {}
}

dependency "cluster" {
  config_path = "../cluster"

  mock_outputs = {
    cluster_connection = {
      api_server_url = ""
      client_cert = ""
      client_key = ""
      ca_crt = ""
    }
  }
}

inputs = {
  cluster_connection = dependency.cluster.outputs.cluster_connection
}
