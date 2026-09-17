# Deploying the docs site

The docs app in `examples/` runs on Fly.io as `rails-ui-kit-docs`
(<https://rails-ui-kit-docs.fly.dev>): one `shared-cpu-1x` machine with 512MB in `ord`. It stops
when idle and starts on the next request, so the first visit after a quiet spell takes a couple
of seconds.

There is no database, and no volume: the demos keep their state in memory, so it resets whenever
the machine stops. That also means a visitor's edit to a demo record is seen by others until then.

## What deploys it

`.github/workflows/deploy-docs.yml` runs on every pushed `v*` tag, so a release (`RELEASING.md`)
publishes its docs. Run it by hand from the Actions tab for anything in between. It runs, from the
repo root:

```bash
fly deploy . --config examples/fly.toml --dockerfile examples/Dockerfile --remote-only
```

The build context is the **repo root**, not `examples/`: the app boots from the gem's `Gemfile`
and renders the gem's own `app/`, `config/` and `docs/guides/`. `.dockerignore` at the root keeps
the rest out.

The workflow needs one repository secret, `FLY_API_TOKEN`: a deploy token scoped to this app
(`fly tokens create deploy -a rails-ui-kit-docs`), not a personal token. The app itself needs one
Fly secret, `SECRET_KEY_BASE`; without it the app refuses to boot and the deploy fails its health
check.

## The image

`examples/Dockerfile` has three stages:

- **gems** installs the runtime gems: the default group and `:docs` (Puma, Thruster, Propshaft,
  importmap, Turbo).
- **build** adds `:assets` (`tailwindcss-rails`) and runs `assets:precompile`, which builds the
  Tailwind CSS.
- **runtime** copies the gems and the compiled app, without the Tailwind binary, and runs as a
  non-root user. Thruster listens on 8080 and proxies to Puma. It compresses responses and caches
  the assets.

`Gemfile.lock` is gitignored, as it is for most gems, so every build resolves its gems fresh from
the `Gemfile`, the way CI does. A new release of a dependency reaches the next deploy without a
commit. The `json < 3` pin in the `Gemfile` exists because of exactly that.

## Running it locally

From the repo root:

```bash
docker build -f examples/Dockerfile -t rails-ui-kit-docs .
docker run --rm -p 8080:8080 \
  -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  -e RAILS_HOSTS=localhost \
  rails-ui-kit-docs
```

Then open <http://localhost:8080>. Health check: `curl localhost:8080/up`.

## Adding a custom domain

1. `fly certs add docs.example.com -a rails-ui-kit-docs`
2. At the DNS provider, add a `CNAME` from `docs.example.com` to `rails-ui-kit-docs.fly.dev`, then
   wait for `fly certs check docs.example.com -a rails-ui-kit-docs` to report the certificate
   issued.
3. Allow the host: set `RAILS_HOSTS = "docs.example.com"` under `[env]` in `examples/fly.toml`
   (comma-separate several) and deploy. `<app>.fly.dev` stays allowed.
