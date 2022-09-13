include {
  path           = find_in_parent_folders()
  merge_strategy = "deep"
}

dependency "metal" {
  config_path = "../metal"

  mock_outputs = {
    nodes = {
      node00 = { ipv4_address = "0.0.0.0" }
    }
    ssh_key = {
      private_key_pem    = "privatekey"
      public_key_openssh = "publickey"
    }
    ingress_ips = ["0.0.0.0"]
  }
}

inputs = {
  nodes         = dependency.metal.outputs.nodes
  ssh_key       = dependency.metal.outputs.ssh_key
  ingress_ips   = dependency.metal.outputs.ingress_ips
}
