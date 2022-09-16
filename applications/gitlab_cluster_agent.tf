resource "gitlab_cluster_agent" "agent" {
  name    = "agent"
  project = var.gitlab_project_id
}

resource "gitlab_repository_file" "agent_config" {
  project        = var.gitlab_project_id
  branch         = "main"
  file_path      = ".gitlab/agents/${gitlab_cluster_agent.agent.name}/config.yaml"
  content        = <<EOF
ci_access:
  projects:
    - id: ${var.gitlab_project_id}
EOF
  author_email   = "terraform@bababourbaki.dev"
  author_name    = "Terraform"
  commit_message = "feature: add agent"
}

resource "gitlab_cluster_agent_token" "agent" {
  project  = var.gitlab_project_id
  agent_id = gitlab_cluster_agent.agent.agent_id
  name     = "agent-token"
}

resource "helm_release" "agent" {
  name = "gitlab-agent"
  # repository       = "https://charts.gitlab.io"
  chart            = "gitlab/gitlab-agent"
  version          = "1.5.0"
  namespace        = "gitlab-agent"
  create_namespace = true

  set {
    name  = "image.tag"
    value = "v15.4.0"
  }

  set {
    name  = "config.token"
    value = gitlab_cluster_agent_token.agent.token
  }

  set {
    name  = "config.kasAddress"
    value = "wss://kas.gitlab.com"
  }
}

# helm repo add gitlab https://charts.gitlab.io
# helm repo update
# helm upgrade --install test gitlab/gitlab-agent \
#     --namespace gitlab-agent \
#     --create-namespace \
#     --set image.tag=v15.4.0 \
#     --set config.token=Pn8yXdZ3Jx8pYFA1SBrUbj9QPZQgrEVfFAFVpuCJBaSxKWJ79A \
#     --set config.kasAddress=wss://kas.gitlab.com
