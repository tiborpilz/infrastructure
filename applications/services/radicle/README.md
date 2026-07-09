# Radicle

A self-hosted [Radicle](https://radicle.xyz) node — peer-to-peer, git-native
code collaboration — deployed as an ArgoCD `Application`.

## Components

| Component        | Image                          | Port | Exposure |
|------------------|--------------------------------|------|----------|
| `radicle-node`   | `fredix/radicle-node:1.6.1`    | 8776 | ClusterIP (internal) |
| `radicle-httpd`  | `fredix/radicle-httpd:0.23.0`  | 8080 | `https://radicle.tibor.sh/api` |
| Explorer (web UI)| `khuedoan/radicle-explorer`    | 80   | `https://radicle.tibor.sh/` |

`radicle-node` and `radicle-httpd` run in a single pod because they share one
`ReadWriteOnce` volume (`RAD_HOME=/radicle`, the `radicle-home` PVC), which
holds the node identity key and the git storage. The Explorer is a separate,
stateless Deployment.

A single hostname (`radicle.tibor.sh`) fronts both: the `HTTPRoute` sends
`/api` to `radicle-httpd` and everything else to the Explorer, so the browser
SPA and the API share an origin (no CORS).

## Node identity

The `fredix` images bundle only the daemon binaries (no `rad` CLI), so they
expect a pre-created profile. Radicle node keys are standard OpenSSH Ed25519
keys, so the `init-identity` container generates a passphrase-less key with
`ssh-keygen` on first boot and persists it on the PVC. Read the Node ID from
the init container logs:

```
kubectl -n radicle logs deploy/radicle -c init-identity
```

`config.json` is declarative — it is copied from the `radicle-node-config`
ConfigMap on every start.

## Post-deploy checks

1. **API reachability:** `curl https://radicle.tibor.sh/api/v1` should return
   JSON including the node's `id` and an `apiVersion`.
2. **Explorer ↔ httpd compatibility:** the Explorer only talks to an httpd
   whose `apiVersion` satisfies `nodes.requiredApiVersion` in
   `explorer-config.yaml` (currently `>=0.18.0`). If the UI reports a version
   mismatch, set that range to match the `apiVersion` from step 1. Also, the
   Explorer only reads the runtime `config.json` if its image was built with
   `VITE_RUNTIME_CONFIG=true`; if it ignores our preferred seed, pin a
   different Explorer image tag/build.

## Making it a public seed

The P2P port (8776) is internal for now. To accept inbound peer connections:

1. Change the `radicle-node` Service to `type: LoadBalancer` with the Hetzner
   annotations (see `../tangled/knot/services.yaml` for the pattern) and an
   `external-dns` hostname.
2. In `node-config.yaml`, add `"externalAddresses": ["radicle.tibor.sh:8776"]`
   and, for an open fully-replicating seed, set
   `"seedingPolicy": {"default": "allow", "scope": "all"}`.
