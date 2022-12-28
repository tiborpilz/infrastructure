include {
  path = find_in_parent_folders()
  merge_strategy = "deep"
}

dependency "cluster" {
  config_path = "../cluster"

  mock_outputs = {
    cluster_connection = {
      host = ""
      cluster_ca_certificate = ""
      client_certificate = ""
      client_key = ""
    }
  }
}

inputs = {
  cluster_connection = dependency.cluster.outputs.cluster_connection
}
