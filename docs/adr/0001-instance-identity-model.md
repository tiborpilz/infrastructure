# ADR 0001: Instance identity via plain files + one config + an idempotent rewrite script

Status: accepted · Date: 2026-07-03

## Context

This repository is simultaneously two things:

1. the **live GitOps source of truth** for one running cluster — ArgoCD syncs
   the default branch with `automated: {prune, selfHeal}`, so everything on it
   must stay directly consumable YAML/HCL at all times;
2. the **template** other organizations should be able to adopt ("turnkey,
   re-brandable").

The instance identity (apex domain, GitOps repo URL, ACME email, cluster
name) appeared ~90 times across the tree. The Terraform layer already
funneled identity through `terragrunt/env.hcl` variables, but the
`applications/` layer carried it as literals in every Application manifest,
HTTPRoute, and Authentik blueprint. A previous attempt at app-layer
templating (`$(DOMAIN)` kustomize vars and `*.yaml.tpl` files) was abandoned
midway and survived only as orphaned dead files — evidence that continuous
templating fights this repo's plain-YAML, grep-able style.

## Decision

- **One identity file**: `config/platform.yaml` (flat keys: `domain`,
  `repo_url`, `acme_email`, `cluster_name`) is the single source of truth.
- **Terraform reads it directly**: `terragrunt/env.hcl` yamldecodes the file,
  so the bootstrap layer (gateway, wildcard cert, DNS, ArgoCD, the root
  Application) follows it without any literals.
- **The application layer stays literal**, and `scripts/rebrand` rewrites the
  literals: it substitutes old→new for each config value across all tracked
  files (including `config/platform.yaml` itself, so config and tree change
  in the same commit), refuses to leave unexpected occurrences of the old
  identity behind, and prints a manual-review checklist for identity the
  substitution must not decide (admin usernames, AT-Protocol handles/DIDs,
  site facts). It is idempotent; re-running with the current config is a
  no-op. CI runs a round-trip against `config/platform.example.yaml` on every
  push.
- **Adoption is a fork** (or GitHub "Use this template"): run
  `scripts/rebrand my-config.yaml`, then `scripts/init-keys` (new sops/age
  keys + secrets seeded from the committed `*.enc.yaml.example` skeletons).
  Upstream improvements arrive via ordinary `git merge`; after a rebrand the
  identity values are the only systematic divergence, and they are
  concentrated in small, mergeable hunks.

## Alternatives considered

- **Copier/cookiecutter template**: best-in-class update story
  (`copier update` three-way merge), but the repo would stop being directly
  consumable — either the tree becomes jinja templates (breaking the live
  instance) or a second, generated template artifact must be maintained
  alongside the instance. Rejected for now; the rebrand script gives 80% of
  the value with zero runtime or repo-shape changes, and a copier layer can
  still be generated *from* this model later.
- **Runtime parameterization** (convert the app layer to Helm charts /
  ApplicationSets templating `domain` and `repoURL` everywhere): cleanest
  multi-instance story, no fork divergence, but it is a rewrite of the entire
  delivery path (and ksops render-time decryption does not carry over to Helm
  sources). This is where the phase-2 "golden path / platform-app chart" work
  goes; not a rebranding prerequisite.
- **Kustomize vars/replacements**: already tried and abandoned in this repo;
  kustomize deliberately refuses general string interpolation (values inside
  URLs like OIDC issuers need delimiter tricks per field). Not revisited.

## Consequences

- The tree is always valid and grep-able; there is no render step between
  git and the cluster.
- A rebrand is a single reviewable commit whose diff *is* the identity change.
- `*.enc.yaml` files cannot be rewritten by substitution (sops MACs cover the
  file); fresh instances re-create them from the `.example` skeletons via
  `scripts/init-keys`, existing instances rotate with `sops updatekeys`.
- The old identity may legitimately survive in an explicit allowlist
  (currently the Authentik users blueprint and encrypted files); the script
  fails on any other leftover, and CI enforces the invariant that
  `config/platform.yaml` matches the tree.
- Forks diverge from upstream in exactly the substituted literals; merges
  conflict only where upstream edited the same lines (accepted trade-off; a
  future ApplicationSet/chart layer shrinks the literal surface further).
