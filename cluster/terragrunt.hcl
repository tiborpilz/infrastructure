remote_state {
  backend = "local"
  config = {}
    # path = "/tmp/local_tg/terraform.tfstate"
  # }
}

dependency "metal" {
  config_path = "../metal"

  # mock_outputs_allowed_terraform_commands = ["validate"]
  mock_outputs = {
    nodes = {
      node00 = { ipv4_address = "0.0.0.1" }
    }
    ssh_key = {
      private_key_pem = "privatekey"
      public_key_openssh = "publickey"
    }
  }
}

inputs = {
  nodes = dependency.metal.outputs.nodes
  ssh_key = dependency.metal.outputs.ssh_key
}
