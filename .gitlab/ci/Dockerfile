FROM registry.gitlab.com/gitlab-org/terraform-images/stable:latest

# Install Terragrunt
RUN ( curl -sLo terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/v0.42.5/terragrunt_linux_amd64" && \
      chmod +x terragrunt && \
      mv terragrunt /usr/local/bin/terragrunt \
    ) && terragrunt --version
