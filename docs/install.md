# Installing syl4

Everything needed to go from a fresh machine to your first verified run: what
you need first, how to install, how to verify what you downloaded, and how
to connect your data.

## Prerequisites

- **macOS or Linux** for the install script below. On Windows you
  download the binary by hand instead — see [Windows](#windows) below.
- **A container engine, running** — Docker, Podman, or nerdctl. syl4 runs
  each query in a sandboxed container; `setup` checks that the engine's
  daemon is actually up, not merely installed.
- **[Claude Code](https://claude.com/claude-code)** — how you talk to syl4.
  Required unless you take the terminal-only route (`syl4 -i "<question>"`,
  `setup --skip-mcp`).
- Connection details (host, database, credentials) for the database you want
  to ask questions of. syl4 supports **MySQL, PostgreSQL, and Amazon
  Redshift**.

## Step 1 — Install the CLI

**If you installed the syl4 [Claude Code plugin](https://github.com/sylmarel/syl4-releases)
from this repository's marketplace**
(`/plugin marketplace add sylmarel/syl4-releases`, then
`/plugin install syl4@syl4`), stop here
— the plugin runs its own guided install (`/syl4:install`) that ends with
`/reload-plugins` rather than the steps below, and running `syl4 setup`
without `--skip-mcp` after installing the plugin registers a second,
colliding `syl4` MCP server. See
[troubleshooting.md](./troubleshooting.md#the-syl4-mcp-server-appears-twice-or-is-broken-after-installing-the-plugin)
if you've already hit that. This page is for everyone else: opencode, other
harnesses, or the terminal-only route.

```sh
curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh | sh
```

This picks the right binary for your machine, checks the download arrived
intact, and installs to `~/.syl4/bin/syl4` — no `sudo`, none of the security
prompts a macOS browser download triggers.

`~/.syl4/bin` is usually not on your `PATH`. The installer prints the exact
line to add; until you run it, use the full path — `~/.syl4/bin/syl4` —
wherever these instructions say `syl4`.

To pin a version, or install somewhere other than `~/.syl4/bin`:

```sh
curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh \
  | SYL4_VERSION=v0.0.1 SYL4_INSTALL_DIR=~/bin sh
```

Both settings must go **after** the `|`, in front of `sh` — in front of
`curl` they're silently ignored and you get a default install. The install
directory has to be one you can write to without `sudo`.

### Windows

There's no install script. Download `syl4-windows-<arch>.exe` from the
[releases page](https://github.com/sylmarel/syl4-releases/releases). To
remove syl4 later, run `syl4 unregister`, then delete the `.syl4` folder
in your user profile (`%USERPROFILE%\.syl4`).

## Verifying what you downloaded

The installer prints `Checksum verified.` before installing — read that
narrowly: it shows your download arrived intact, not that the right file was
published.

The stronger check is optional and you run it yourself. It needs
[GitHub's `gh` CLI](https://cli.github.com/), though not a GitHub account.
The installer saves a signature file beside the binary, so after installing:

```sh
gh attestation verify ~/.syl4/bin/syl4 \
  --bundle ~/.syl4/bin/syl4.attestation.jsonl \
  --repo sylmarel/sylpy \
  --signer-workflow sylmarel/sylpy/.github/workflows/cli-release.yml
```

A pass means those exact bytes came out of syl4's release pipeline. **If it
fails, do not run the binary — tell your syl4 contact.** For a binary you
downloaded by hand, the same signature file is on the
[releases page](https://github.com/sylmarel/syl4-releases/releases) — point
`--bundle` at your copy. The same command with `SHA256SUMS` in place of
the binary path verifies that file too. On a restricted network the check
needs to reach `tuf-repo.github.com` and `tuf-repo-cdn.sigstore.dev`.

Installing with `SYL4_SHOW_VERIFY=1` set makes the installer print this
command for you, filled in with your paths:

```sh
curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh \
  | SYL4_SHOW_VERIFY=1 sh
```

Like the version pin above, the setting goes after the `|`, in front of
`sh`. The installer never runs the
check itself: it arrives with the download, so anyone able to replace the
binary could equally delete the check.

The `--repo` and `--signer-workflow` values above are what make the check
mean anything — a signature alone only proves *some* pipeline produced the
file. They have to reach you from somewhere other than the download, and
this page is served from the same repository as the binaries, so anyone who
could swap a binary here could edit this page too. Ask the person who
invited you to syl4 to send you the verify command, and run the one they
send — if it doesn't match the one above, stop and tell them.

## Step 2 — One-time setup

```sh
SYL4_ADDR=<your cluster address> syl4 setup
```

Use the address you were given when you were invited.

`setup` checks every prerequisite before writing any state — a missing one
names itself with install instructions, so nothing is left half-installed —
then signs you in through your browser, registers the syl4 MCP server with
Claude Code, and installs the syl4 skill, scoped to the current project's
`./.claude/skills` by default. Re-running `setup` later with no scope flag
is safe and upgrades the skill in place without moving it; passing
`--global` (every Claude Code session) or `--project` explicitly switches
the install to that scope and sweeps the copy at the previous location, so
exactly one stays installed.

Alongside the syl4 skill, `setup` installs a small demo extra: the
**`no-syl4`** skill and a bundled benchmark it runs (extracted to
`~/.syl4/benchmarks/bird`). Invoking `/no-syl4` in a session runs a
question through a plain, unverified LLM call — no formalization, no
proofs — so you can put its SQL and answer side by side with a syl4 run
of the same question. Pass `--skip-benchmark` to leave the pair out.

At a terminal, `setup` ends by offering to register your first datasource
connection:

```text
Add a datasource connection now? [Y/n]: y
connection name (e.g. mydb): <name>
# paste the connection URL, then Ctrl-D:
#   mysql://<user>:<password>@<host>:3306/<database>
#   postgresql://<user>:<password>@<host>:5432/<database>
#   redshift://<user>:<password>@<host>:5439/<database>
```

The URL needs its `scheme://` prefix and is read at a hidden prompt, never
echoed or kept in shell history; the password moves straight into
`~/.syl4/env`, never into the registry file — connection details stay on
your machine. If you skip this, or `setup` runs unattended (no TTY), register
one any time with `syl4 connections add --url-stdin <name>` and check it
with `syl4 connections check --datasource <name>`.

If your organization has already captured your schema as a named datasource,
use that exact name as the connection name — a run looks its connection up
by the datasource name, and a mismatch stops the run at preflight with
`missing datasource connections`.

Two variations of the setup command, if they apply to you:

```sh
SYL4_ADDR=<your cluster address> syl4 setup --skip-mcp     # no Claude Code: terminal-only route
SYL4_ADDR=<your cluster address> syl4 setup --skip-login   # headless/remote box: sign in later
```

Without `--skip-mcp`, `setup` stops with an error if `claude` isn't on your
`PATH`. Since sign-in opens a browser on the machine running `setup`, use
`--skip-login` on a headless or remote box and run `syl4 login` later from
somewhere with a browser.

Once it finishes, `syl4 version` should show a version, the build's commit,
and that commit's date. If you use Claude Code, `claude mcp list` should now
show a `syl4` entry — its URL is your cluster address with `/mcp` on the
end, which is expected, not a typo.

## Step 3 — Ask your first question

Open Claude Code in the directory where you ran `setup` — that's where the
skills were installed (with `--global` any directory works; the MCP server
itself is registered machine-wide either way). The syl4 MCP server needs
one more thing before it can run tools: **run `/mcp` and authorize the
`syl4` server** — this is a separate, Claude-Code-side OAuth step from the
sign-in `setup` already did for the CLI itself, and Claude Code will prompt
for it again if a session's authorization ever expires. (This is the
script-install route's connect step — if you used the Claude Code plugin
instead, the equivalent step is `/reload-plugins`, per the plugin's own
install skill, not `/mcp`.)

Once `/mcp` shows `syl4` as connected, prefix any prompt with `syl4`:

> syl4 \<your question\>

Or, from a terminal, without a chat host at all:

```sh
syl4 -i "<your question>"
```

Pick a first question whose answer you already know — a count you can
eyeball, last month's total, anything you could check by hand — so the run
doubles as a correctness check, not just a smoke test. Either way you'll
watch the run get formalized, planned, and verified in the cloud, then
executed next to your data, and you can inspect the typed program it ran,
not just the answer.

From here, [using.md](./using.md) covers everything else you can do in a
session — teaching syl4 your vocabulary, reviewing the SQL before a run,
inspecting past runs — and [cli.md](./cli.md) is the full command
reference.

## Something not working?

See [troubleshooting.md](./troubleshooting.md) for common failures and
fixes, and [known-issues.md](./known-issues.md) for the current limitations.
For anything else, ask the person who invited you to syl4 — issues and pull
requests on this repository aren't monitored.
