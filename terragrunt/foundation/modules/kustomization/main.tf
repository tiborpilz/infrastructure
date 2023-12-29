locals {
  overlay_dir = "${var.kustomize_dir}/overlay"
  out_dir       = "${var.kustomize_dir}/out"
}

resource "null_resource" "kustomize" {
  triggers = {
    overlay_dir = local.overlay_dir
    out_dir       = local.out_dir
  }
  provisioner "local-exec" {
    command = "mkdir -p ${local.overlay_dir} ${local.out_dir}"
  }
}

resource "local_file" "kustomization" {
  filename = "${local.overlay_dir}/kustomization.yaml"
  content  = yamlencode(var.overlay) # TODO: only use patches?
}

resource "null_resource" "kustomize_build" {
  depends_on = [null_resource.kustomize, local_file.kustomization]
  triggers = {
    kustomization = local_file.kustomization.content
  }
  provisioner "local-exec" {
    command = "kustomize build ${local.overlay_dir} -o ${local.out_dir}/manifests.yaml"
  }
}

data "local_file" "manifests" {
  depends_on = [null_resource.kustomize_build]
  filename = "${local.out_dir}/manifests.yaml"
}

output "manifests" {
  value = data.local_file.manifests
}
