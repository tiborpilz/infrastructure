data "gitlab_group" "bababourbaki" {
  full_path = "baba-bourbaki"
}

resource "gitlab_runner" "cluster_runner" {
  registration_token = data.gitlab_group.bababourbaki.runners_token
  description        = "Default Cluster Runner"
}

resource "helm_release" "gitlab_runner" {
  name             = "gitlab-runner"
  repository       = "https://charts.gitlab.io"
  chart            = "gitlab-runner"
  version          = "0.23.0"
  namespace        = "gitlab"
  create_namespace = true

  values = [<<EOF
gitlabUrl: https://gitlab.com
runnerRegistrationToken: ${data.gitlab_group.bababourbaki.runners_token}
EOF
  ]
}
