# syl4 CLI reference

The `syl4` binary is the half of syl4 that runs on your machine: it sets
the client up, holds your datasource connections, and executes prepared
runs next to your data. Day to day you rarely type it — in a Claude Code
session, Claude runs `syl4 execute` for you — but it's what the
terminal-only route uses, and it's where connections, credentials, and
telemetry are managed. `syl4 <command> -h` prints each command's flags.

Commands that talk to the cluster take `--addr <gateway-url>`; without it
they use `SYL4_ADDR`, then the address `setup` stored in
`~/.syl4/config.json`. You normally set the address once, at setup, and
never pass it again.

## `syl4 setup`

One-time setup, covered step by step in [install.md](./install.md): checks
every prerequisite before writing any state, signs you in through your
browser, registers the syl4 MCP server with Claude Code, and installs the
syl4 skill. Safe to re-run; a re-run upgrades the skill in place.

```sh
SYL4_ADDR=<your cluster address> syl4 setup
```

| Flag | What it does |
| --- | --- |
| `--addr <gateway-url>` | Cluster address (or `SYL4_ADDR`). |
| `--engine <name>` | Container engine: `docker`, `podman`, or `nerdctl` (default: `SYL4_ENGINE`, then detection). |
| `--global` / `--project` | Install the Claude Code skill for every session (`~/.claude/skills`) or this project (`./.claude/skills`, the default for a first install). Passing either explicitly moves the install to that scope. |
| `--skip-mcp` | Skip Claude Code MCP registration — the terminal-only route. |
| `--skip-skill` | Skip installing the syl4 skill. |
| `--skip-benchmark` | Skip extracting the raw-LLM benchmark to `~/.syl4/benchmarks/bird` and installing the no-syl4 skill (implied by `--skip-skill`). |
| `--skip-login` | Skip the browser sign-in; run `syl4 login` later. For headless or remote boxes. |

At a terminal, `setup` ends by offering to register your first datasource
connection — see [`syl4 connections`](#syl4-connections--the-datasource-registry) below.

## `syl4 login` / `syl4 logout`

Sign the CLI in to (or out of) the cluster through your browser. `setup`
signs you in already; `login` is for `--skip-login` installs and for
sessions that have expired. Note the Claude-Code-side `/mcp` authorization
is a separate step — see
[known-issues.md](./known-issues.md#mcp-authorization-and-cli-sign-in-are-two-separate-steps).

## `syl4 -i` — run questions without Claude Code

```sh
syl4 -i "<your question>"   # one question, then exit
syl4 -i                     # read questions interactively
```

Runs prompts end to end — cloud synthesis, then local execution — with no
chat host. It shares `execute`'s flags below (`--addr`, `--network`,
`--connections`, `--env`, `--env-file`, `--no-report`, `--telemetry`,
`--engine`, `--image`), plus `--flavor` to override the deployment's
default plan flavor for each run.

## `syl4 execute` — run a prepared run

```sh
syl4 execute --run <run_id>
```

Fetches the prepared run's verified bundle by id, runs it in a sandboxed
container next to your data, streams the output, and reports the outcome
(success or failure — never the results) to the cluster. Each execution is
recorded under `~/.syl4/executions/<run_id>/`: `result.txt` (the program's
output), `executor.log`, and `meta.json` (exit status and duration).

| Flag | What it does |
| --- | --- |
| `--run <run_id>` | The run to execute (required). |
| `--network <name>` | Container network, for datasource reachability (e.g. `syl4-data`), or `none` for isolation. |
| `--connections <path>` | `connections.yaml` to use (default: `~/.syl4/connections.yaml`). |
| `--env NAME` | Additionally require and pass this variable, resolved from the environment, `--env-file`, then `~/.syl4/env` (repeatable). |
| `--env-file <path>` | Extra `KEY=VALUE` credential file (mode 0600). Only keys a connection or `--env` names reach the container. |
| `--arg <value>` | Program argument, for runs that take input (repeatable). |
| `--no-report` | Skip reporting the outcome to the cluster. The run stays `prepared` server-side until a later execution reports. |
| `--telemetry <mode>` | Execution telemetry: see below. |
| `--engine <name>` | Container engine override (default: `SYL4_ENGINE`, then the engine `setup` validated, then detection). |
| `--image <ref>` | Executor image override (default: the image the run's bundle was prepared against). |

If the run exits naming a missing credential, add it to `~/.syl4/env`
(`KEY=VALUE`, mode 0600) or export it, and re-run the same command —
credentials never go on the command line.

### Execution telemetry

`execute` (and `-i`) emit minimal execution telemetry: outcome and timing
only — never the program's output, your rows, or credentials. Three modes,
via `--telemetry` or `SYL4_CLIENT_TELEMETRY`:

- `push` (default) — capture locally and send to the cluster.
- `local` — capture locally only, under
  `~/.syl4/executions/<run_id>/telemetry/`.
- `off` — disable capture entirely.

## `syl4 connections` — the datasource registry

```sh
syl4 connections add [--force] <name> <url>
syl4 connections add [--force] --url-stdin <name>
syl4 connections list
syl4 connections check [--datasource <name>]
```

The registry lives at `~/.syl4/connections.yaml` and maps a datasource
name to a connection URL:

```text
mysql://app:${DB_PASSWORD}@db.example.com/app
```

A `${VAR}` credential is resolved when the program runs — put the value in
`~/.syl4/env` (`KEY=VALUE`, mode 0600) or export it in your shell — and no
subcommand ever prints a credential value. Use `--url-stdin` when the
password is inline in the URL: the URL is read at a hidden prompt (never
echoed, never in shell history) and `add` moves the password into
`~/.syl4/env` for you. The connection name must match the datasource name
your organization registered on the cluster —
see [known-issues.md](./known-issues.md#one-connection-registry-per-machine-one-credential-per-name).

`check` reports which variables each connection needs — by name, never by
value — and whether they resolve, exiting non-zero when any doesn't.
`--datasource <name>` (repeatable) narrows the check to what a run needing
that connection would require; it also takes `--connections`, `--env-file`,
and `--env` with the same meanings as `execute`.

## `syl4 telemetry push`

```sh
syl4 telemetry push <run_id>
```

Ships a run's locally captured telemetry to the cluster after the fact —
for deliberately sharing a specific run that was executed with
`--telemetry local`. It only forwards what's already on disk; it never
re-runs anything.

## `syl4 unregister`

Reverses what `setup` wrote on this machine: the MCP registration, the
installed skill, the stored sign-in credential (revoked at the cluster
first), and the stored cluster address. Everything it removes is
ownership-checked — it skips, with an explanation, anything it didn't
install. Your data stays: execution records and the connection registry
under `~/.syl4` are always kept. `--yes` skips the confirmation prompt.

To remove syl4 entirely, run `syl4 unregister`, then delete `~/.syl4`.

## `syl4 version`

Prints the version, the build's commit, and that commit's date — the
quickest check that an install or upgrade landed.

## Files under `~/.syl4`

| Path | What it holds |
| --- | --- |
| `bin/syl4` | The binary (default install location). |
| `config.json` | The cluster address `setup` stored (non-secret). |
| `credentials.json` | The stored sign-in token (mode 0600), written by `setup`/`login`, removed and revoked by `logout`/`unregister`. `credentials.lock` sits beside it. |
| `connections.yaml` | The datasource registry — names and URLs, no passwords. |
| `env` | `KEY=VALUE` credentials (mode 0600), referenced as `${VAR}` from connection URLs. |
| `executions/<run_id>/` | Per-run execution records: `result.txt`, `executor.log`, `meta.json`, captured telemetry. |
