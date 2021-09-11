include {
  path = find_in_parent_folders()
  merge_strategy = "deep"
}

remote_state {
  backend = "local"
  config = {}
    # path = "/tmp/local_tg/terraform.tfstate"
  # }
}
