include {
  path           = find_in_parent_folders()
  merge_strategy = "deep"
}

dependency "foundation" {
  config_path = "../foundation"

  mock_outputs = {
    nodes = {
      node00 = { ipv4_address = "0.0.0.0", role = ["control", "worker", "etcd"] }
    }
    ssh_key = {
      private_key_pem    = "privatekey"
      public_key_openssh = "publickey"
    }
    ingress_ips = ["0.0.0.0"]
  }
}

inputs = {
  nodes       = dependency.foundation.outputs.nodes
  ssh_key     = dependency.foundation.outputs.ssh_key
  ingress_ips = dependency.foundation.outputs.ingress_ips
}
