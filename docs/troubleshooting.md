# Troubleshooting

Common failures, what they mean, and how to fix them. See
[install.md](./install.md) for the full install/setup walkthrough this
assumes.

## `command not found: syl4`

`~/.syl4/bin` isn't on your `PATH`. The installer printed the exact line to
add it — run that, open a new shell, or use the full path
(`~/.syl4/bin/syl4`) in the meantime.

## `error: no gateway address: pass --addr <url> ... or set SYL4_ADDR`

`setup` (or `login`/`execute`/`-i`) was run without a configured address.
Pass `--addr <url>` or set `SYL4_ADDR=<your cluster address>` on that same
command — e.g. `SYL4_ADDR=<your cluster address> syl4 setup`. Once `setup`
has run successfully once with an address, it's saved to
`~/.syl4/config.json` and later commands don't need it again.

## `error: no container engine found on PATH (need one of docker, podman, nerdctl)`

No `docker`, `podman`, or `nerdctl` binary is on your `PATH` at all. Install
[Docker Desktop](https://docs.docker.com/get-docker/) or
[Podman](https://podman.io/docs/installation). If you have more than one
engine installed and want a specific one, pass `--engine <name>` or set
`SYL4_ENGINE`.

## `error: <engine> is installed but its daemon is not responding`

The binary is on `PATH`, but its daemon isn't answering — `setup` checks
liveness (`docker info` / equivalent), not just that the binary exists on
disk. Start Docker Desktop, or the `docker`/`podman` service, and re-run.

## `error: Claude Code ('claude') not found on PATH`

`setup` registers the syl4 MCP server with Claude Code by default, which
needs the `claude` binary on `PATH`. Either install
[Claude Code](https://claude.com/claude-code), or pass `--skip-mcp` to take
the terminal-only route (`syl4 -i "<question>"`).

## The syl4 skill or MCP server isn't showing up in a Claude Code session

The skill installs project-scoped by default: `setup` writes it to
`./.claude/skills` under the directory you ran it from, so it's only live in
Claude Code sessions opened in that project. Either open Claude Code from
that same directory, or re-run `syl4 setup --global` to explicitly move the
install to `~/.claude/skills` (available to every session) — a bare re-run
with no scope flag leaves it where it already is. `claude mcp list` shows
the registered server independent of the skill's scope.

## `syl4` tools aren't callable even though `claude mcp list` shows the server

`setup` signs the CLI in, but Claude Code still needs its own authorization
for the remote MCP connection. In a Claude Code session, run `/mcp` and
authorize `syl4` — this can also happen again later if a session's
authorization expires; running `/mcp` again fixes it without re-running
`syl4 setup`.

## `error: '<value>' is not a connection URL (expected scheme://host/db)`

`syl4 connections add` (or the connection prompt at the end of `setup`)
refuses a bare host — the URL needs its scheme, e.g.
`mysql://user:password@host:3306/database`,
`postgresql://user:password@host:5432/database`, or
`redshift://user:password@host:5439/database`.

## A run fails at preflight with `missing datasource connections: <name>`

The run references a datasource connection by name, and nothing in your
local registry matches it. Register the connection under that **exact**
name: `syl4 connections add --url-stdin <name>`, then confirm with
`syl4 connections check --datasource <name>`. This is almost always a
name mismatch, not a missing credential.

## `error: connection "<name>" already exists`

Re-registering a name that's already in the registry. Overwrite it with
`syl4 connections add --force --url-stdin <name>`, which pastes the URL at
a hidden prompt just like a first-time registration — or pick a different
name if you meant to add a second connection. Avoid passing the URL as a
plain argument: that puts the credential in your shell history and process
list.

## The syl4 MCP server appears twice, or is broken, after installing the plugin

The Claude Code plugin this repository ships
(`/plugin marketplace add sylmarel/syl4-releases`, then
`/plugin install syl4@syl4`) owns and registers its own `syl4` MCP server
— its guided install
(`/syl4:install`) always runs `syl4 setup --skip-mcp` for exactly this
reason. Running a bare `syl4 setup` (the route in
[install.md](./install.md)) after installing the plugin registers a second,
user-scoped `syl4` MCP entry that collides with the plugin-owned one.

Check for the collision with `claude mcp get syl4`, and remove the stray
user-scoped registration with `claude mcp remove -s user syl4`. Then use
`/reload-plugins` (not `/mcp`) to (re)connect the plugin's own server — see
`/syl4:install` step 5.

## Sign-in doesn't work on a headless or remote machine

`setup`'s sign-in opens a browser on the machine running it, which fails
with nothing to open on a headless box. Run
`syl4 setup --skip-login` there, then run `syl4 login` later from a machine
with a browser (or forward the URL it prints).

## The `gh attestation verify` command fails or can't reach the network

That check needs outbound access to `tuf-repo.github.com` and
`tuf-repo-cdn.sigstore.dev`; a restricted network can block it even when the
binary itself is fine. **Don't run the binary based on assuming it's fine —
tell your syl4 contact** and confirm whether the failure is network-shaped
(timeout/DNS) or a genuine signature mismatch.

## Starting over

`syl4 unregister` reverses what `setup` wrote — the MCP registration, the
installed skill(s), the stored execution credential (revoked at the
cluster), and `~/.syl4/config.json` — after a confirmation prompt (`--yes`
skips it). It leaves `connections.yaml` and `~/.syl4/env` alone. To remove
everything, including your registered connections, delete `~/.syl4` after
unregistering.
