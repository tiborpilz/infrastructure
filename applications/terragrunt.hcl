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
    kube_config_yaml = ""
  }
}

inputs = {
  cluster_connection = dependency.cluster.outputs.cluster_connection
  kube_config_yaml = dependency.cluster.outputs.kube_config_yaml
}
