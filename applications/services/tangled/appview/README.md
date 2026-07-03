# tangled appview

Self-hosted [Tangled](https://tangled.org) appview — the web UI / indexer that
tangled.org itself runs ([source](https://tangled.org/tangled.org/core)).
Served at <https://tangled.tibor.sh>.

Together with the existing pieces in this repo this completes the stack:

| Component | Where | Role |
|---|---|---|
| appview | `tangled/appview` (this dir) | web UI, network indexer, OAuth client |
| knot | `tangled/knot` → `knot.tibor.sh` | git hosting |
| spindle | `tangled/spindle` → `spindle.tibor.sh` | CI |
| PDS | `services/pds` → `pds.tibor.sh` | identity + record storage |

The appview is a single Go binary: SQLite for state (PVC at `/data`), a small
Redis for OAuth sessions (`redis.yaml`, ephemeral — restart logs everyone
out), and a jetstream subscription (public Bluesky jetstream by default) to
ingest `sh.tangled.*` records from the whole network. TLS and DNS for
`tangled.tibor.sh` are covered by the wildcard cert and external-dns like
every other HTTPRoute.

## One-time setup before first sync

ArgoCD will report a build error for this app until `secrets.enc.yaml`
exists. Create it:

```sh
cd applications/services/tangled/appview
cp secrets.enc.yaml.example secrets.enc.yaml
```

Fill in:

- `TANGLED_COOKIE_SECRET`: `openssl rand -hex 16` (must be 32 chars)
- `TANGLED_OAUTH_CLIENT_SECRET` / `_KID`: the atproto OAuth client key.
  Generate with goat and use the "Secret Key (Multibase Syntax)" line
  (`z42...`), plus e.g. `date +%s` as the kid:

  ```sh
  nix run git+https://tangled.org/tangled.org/core#goat -- key generate -t P-256
  ```

Then encrypt (`.sops.yaml` matches `*.enc.yaml` automatically) and commit:

```sh
sops -e -i secrets.enc.yaml
```

## Image

The deployment pins `atcr.io/tangled.org/appview` to the same tag as the knot
(`v1.15.0-alpha`), pulled with the existing `atcr-pull` secret. Verify the tag
exists before merging (atcr.io lists tangled.org's published images):

```sh
docker manifest inspect atcr.io/tangled.org/appview:v1.15.0-alpha
```

If upstream doesn't publish an appview image, build a static binary from the
flake and push it to Harbor instead, then change `image:` in
`deployment.yaml`:

```sh
git clone https://tangled.org/tangled.org/core && cd core
nix build .#pkgsStatic-appview
cat > Dockerfile <<'EOF'
FROM alpine:3.20
RUN apk add --no-cache ca-certificates git
COPY result/bin/appview /usr/local/bin/appview
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/appview"]
EOF
docker build -t harbor.tibor.sh/library/tangled-appview:v1.15.0-alpha .
docker push harbor.tibor.sh/library/tangled-appview:v1.15.0-alpha
```

Keep appview and knot on the same release when bumping either.

## After it's up

1. Log in at `https://tangled.tibor.sh` with your existing handle — atproto
   OAuth against `pds.tibor.sh`. This requires the appview host to be
   publicly reachable (PDSes fetch
   `https://tangled.tibor.sh/oauth/client-metadata.json`).
2. Re-verify the knot on `/knots` and the spindle on `/spindles`. This
   re-puts the `sh.tangled.knot` / `sh.tangled.spindle` records on the PDS,
   which this appview then ingests and verifies (tangled.org re-ingests them
   harmlessly).
3. Re-save your SSH key and profile in settings if they don't show up —
   see the caveat below.

### Expectations / caveats

- **Fresh database, no backfill.** The appview only consumes *live* jetstream
  events (cursor is persisted across restarts, but resets if more than ~2
  days stale). Anything created before this instance started — repos, issues,
  stars, profiles across the network — is not indexed retroactively. Check
  upstream for backfill tooling when bumping versions.
- **The knot keeps working with tangled.org.** Knot API calls are
  authenticated per-user via atproto service auth, not per-appview, so both
  tangled.org and this instance can operate against `knot.tibor.sh`. The
  knot's `APPVIEW_ENDPOINT` (currently `https://tangled.org`) mostly controls
  which appview the knot links to in messages; switch it to
  `https://tangled.tibor.sh` only once this instance has proven itself.
- **Avatars and camo'd images** default to tangled.org's hosted services
  (`avatar.tangled.sh` / `camo.tangled.sh`), which sign URLs with a shared
  secret this instance doesn't have — expect fallback/broken avatars unless
  you also run those services (`TANGLED_AVATAR_*` / `TANGLED_CAMO_*`).
- **Optional integrations, all disabled** by leaving their env unset: email
  notifications (`TANGLED_RESEND_API_KEY`), analytics
  (`TANGLED_POSTHOG_API_KEY`), signup of managed accounts on the PDS
  (`TANGLED_PDS_ADMIN_SECRET` + `TANGLED_CLOUDFLARE_TURNSTILE_*`). Without
  signups, users bring their own atproto account — for a personal instance
  that's what you want.
