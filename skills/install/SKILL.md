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
SYL4_ADDR=<gateway address> ~/.syl4/bin/syl4 setup
```

Setup checks its prerequisites first — a **running** container engine
(Docker, Podman, or nerdctl) and Claude Code — and if one is missing
it names it and exits without changing anything: tell the user what is
missing and stop.

With prerequisites in place, setup registers the syl4 MCP server,
installs the syl4 skill into Claude Code, and finishes by starting the
browser sign-in for the server it just connected to. When it prints a
sign-in URL, show it to the user and wait for them to complete it in
the browser.

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
> One last step: the MCP server that setup registered is only loaded
> when a session starts, so exit this session with `/exit` and pick
> it up again — conversation included — with `claude --continue`.
> Then syl4 runs prompts reliably — try:
> `syl4 what is the sum of first 100 integers`

The exit-and-resume matters: a running session cannot connect an MCP
server registered mid-session, and `claude --continue` restores this
conversation while loading the new registration. The first syl4
prompt will open a browser once more — Claude Code acquires its own
credential for the MCP server on first connect.
