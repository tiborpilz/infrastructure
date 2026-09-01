# Pull-request previews

`preview-demo.yaml` discovers open pull requests in the public
`forgejo_admin/preview-demo` Forgejo repository. Each pull request produces one
Argo CD Application and one isolated namespace:

```text
preview-demo-pr-42
└── namespace preview-preview-demo-42
    └── https://preview-demo-pr-42.preview.tibor.sh
```

Woodpecker publishes the immutable image tag consumed by the ApplicationSet:

```text
harbor.tibor.sh/previews/preview-demo:pr-<number>-<full-head-sha>
```

Closing the pull request removes the generated Application. Its Argo CD
resources finalizer then removes the preview namespace and workloads.

## One-time Woodpecker setup

Enable `forgejo_admin/preview-demo` in Woodpecker and add the Harbor robot
credentials as repository secrets:

- `harbor_username`
- `harbor_password`

Allow both secrets for the `pull_request` event and restrict them to the exact
plugin image `woodpeckerci/plugin-kaniko:2.3.2`. The image restriction matters:
pull-request authors can edit the pipeline, but must not be able to expose the
registry credential from an arbitrary container.

The Harbor robot only needs pull and push access to the `previews` project. The
project is public so preview namespaces require no registry pull secret.

## Trust boundary

Pull-request code runs with no service-account token, no Secrets, a read-only
root filesystem, fixed CPU/memory limits, and default-deny ingress and egress.
Only traffic from the Gateway namespace can enter the pod. The ApplicationSet
keeps the project, source chart, destination prefix, and hostname shape fixed;
pull-request content controls only the container image.

The demo repository is public so ApplicationSet can discover pull requests
without a long-lived Forgejo API token. Before adapting this to a private
repository, create a read-only machine credential rather than reusing an admin
token.
