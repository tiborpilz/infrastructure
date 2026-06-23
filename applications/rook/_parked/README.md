# Parked: native SAML SSO for the Ceph dashboard

Not wired in. The dashboard is served at `ceph.tibor.sh` with Ceph's own local
admin login. These files are kept for a later attempt at native single sign-on.

## Why it's parked

The Ceph dashboard only does SSO via SAML, and SAML behind a TLS-terminating
gateway is officially unsupported: the dashboard sees plain HTTP from the gateway
and rejects the response (`received at http... instead of https...`). Ceph does
not honor `X-Forwarded-Proto` and won't add a scheme override (closed wontfix).
The fix requires end-to-end HTTPS to the dashboard.

- Rook #8633 (closed wontfix), Ceph tracker #48306 ("enable HTTPS in the Dashboard").

## What's here

- `saml.yaml` — Authentik SAML provider + `ceph` application blueprint (valid;
  all `!Find` names verified against live Authentik, `sign_assertion: true`).
- `dashboard-sso.yaml` — Job (+ RBAC) that execs the toolbox to run
  `ceph dashboard sso setup saml2` / `enable` and pre-create the admin user.

## To resume (end-to-end TLS, re-encrypt)

Cilium 1.19 has the `BackendTLSPolicy` CRD, so the gateway can re-encrypt to the
dashboard:

1. Set `cephClusterSpec.dashboard.ssl: true` in `../rook-ceph-cluster.yaml`
   (dashboard then serves HTTPS on 8443).
2. Point `../httproute.yaml` backendRef at `rook-ceph-mgr-dashboard:8443`.
3. Add a `BackendTLSPolicy` targeting the dashboard Service so the gateway
   originates TLS, with a CA the gateway trusts and a matching hostname. The
   awkward part is the backend cert: Ceph stores its dashboard cert in the mon
   config-key (set via CLI, not a mounted secret), so either pin Ceph's
   self-signed CA or load a known cert into Ceph and reload it on renewal.
4. Move `saml.yaml` back to `../blueprints/` and `dashboard-sso.yaml` back to
   `../`, re-add it to `../kustomization.yaml`.

Alternative if e2e-TLS isn't worth the cert maintenance: front the dashboard with
oauth2-proxy (Authentik OIDC) again — robust, but a second Ceph login.
