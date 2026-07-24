---
name: install
description: >-
  Download the syl4 CLI, connect it to a syl4 server, and sign in.
  Use when the user asks to install syl4, set up syl4, or get started
  with syl4 on this machine.
---

# Install syl4

syl4 runs prompts reliably: the cluster turns a prompt into a verified
program, and the syl4 CLI executes it on this machine, next to your
data. This skill takes a machine from nothing to ready — binary
installed, `syl4 setup` run against the user's server, user signed in.

Perform the steps in order; each depends on the one before it. If a
step fails, show the user the error and stop rather than improvising
around it.

## 1. Download the binary

Run the installer that ships with this plugin:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/install.sh"
```

If `CLAUDE_PLUGIN_ROOT` is not set, fall back to the hosted copy of
the same script:

```sh
curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh | sh
```

The installer picks the right binary for this machine, verifies its
checksum, and installs to `~/.syl4/bin/syl4` — no sudo. `~/.syl4/bin`
is usually not on `PATH`: the installer prints the one line that adds
it — relay that line to the user, and use the full path
`~/.syl4/bin/syl4` for the remaining steps.

## 2. Ask for the server domain

Ask the user which syl4 server to connect to. The answer is a server
domain; the default is `demo` — offer it as such, alongside "the
address from your invite" for users joining a private cluster.

Derive the gateway address from the answer:

- already contains `://` → use it as-is
- fully qualified (contains a `.`) → `https://<answer>`
- a bare name, not fully qualified → qualify it with `sylfor.ai`:
  `https://<answer>.sylfor.ai` — so the default `demo` becomes
  `https://demo.sylfor.ai`

## 3. Run setup

```sh
SYL4_ADDR=<gateway address> ~/.syl4/bin/syl4 setup --skip-mcp
```

`--skip-mcp` is deliberate: this plugin ships the syl4 MCP server
itself (a proxy that reads the address setup stores), so setup must
not also register one — two registrations named `syl4` would collide.

Setup checks its prerequisites first — a **running** container engine
(Docker, Podman, or nerdctl) and Claude Code — and if one is missing
it names it and exits without changing anything: tell the user what is
missing and stop.

With prerequisites in place, setup stores the gateway address,
installs the syl4 skill into Claude Code, and finishes by starting the
browser sign-in for the server it just connected to. When it prints a
sign-in URL, show it to the user and wait for them to complete it in
the browser.

If the user ever ran `syl4 setup` WITHOUT this plugin before, a
user-scoped MCP registration may linger and collide with the plugin's:
check with `claude mcp get syl4`, and if one exists, remove it with
`claude mcp remove -s user syl4`.

## 4. Confirm authentication

Setup normally completes sign-in itself. If it was interrupted, or the
user deferred it, initiate it directly:

```sh
~/.syl4/bin/syl4 login
```

A successful sign-in stores the execution credential in
`~/.syl4/credentials.json`.

## 5. Wrap up

Run `~/.syl4/bin/syl4 version`, then confirm to the user along these
lines:

> syl4 `<version>` is installed and signed in to `<gateway address>`.
> One last step: type `/reload-plugins` to connect the syl4 MCP
> server — no need to leave this session. Then syl4 runs prompts
> reliably — try: `syl4 what is the sum of first 100 integers`

`/reload-plugins` is typed by the user, not run by you — it is a
Claude Code command, not a shell command. It connects the MCP server
this plugin ships, which reads the gateway address setup just stored.
The first connection opens a browser once more: the MCP leg acquires
its own credential via the standard MCP OAuth flow, separate from the
`syl4 login` execution credential. The proxy needs Node.js (`npx`) on
`PATH`; if it is missing, say so and point at <https://nodejs.org>.
