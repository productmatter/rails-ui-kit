## Git Treeline

This project uses git-treeline for port and resource allocation.
**Do not assume port 3000.** Ports are dynamically allocated per worktree.

- After creating a worktree, run `gtl setup .` to allocate ports and configure the environment.
- Get the allocated port: `gtl port`
- Full allocation details: `gtl status --json`
- Check if services are running: `gtl status --check`
- Allocated env vars: PORT in `.env`
- Inspect the env file: `gtl env` (add `--json` for structured output)
- Start and wait for readiness: `gtl start --await`
- Resolve another project's URL: `gtl resolve <project> --json`
