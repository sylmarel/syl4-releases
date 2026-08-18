# Known issues and limitations

Things worth knowing before you hit them, not bugs we've lost track of.

## No native Windows install script

Windows has no `install.sh` equivalent. Download
`syl4-windows-<arch>.exe` by hand from the
[releases page](https://github.com/sylmarel/syl4-releases/releases); the
checksum/attestation verification in [install.md](./install.md) still
applies to that binary.

## Skill install is project-scoped by default

Since the project-scoped-install change, `syl4 setup` installs the Claude
Code skill to `./.claude/skills` under the directory you ran it from, not
`~/.claude/skills`. A session opened in a different directory won't see the
skill unless you pass `--global` (installs for every session) or open
Claude Code from that same project.

## MCP authorization and CLI sign-in are two separate steps

`syl4 setup` signs the CLI in and registers the MCP server with Claude Code,
but Claude Code still runs its own OAuth handshake for the connection the
first time you use it — via `/mcp` inside a session. Forgetting this step
looks like the server is registered (`claude mcp list` shows it) but no
`syl4` tools are actually callable.

## One connection registry per machine, one credential per name

`syl4 connections` keys by name, and a run's datasource reference has to
match a registry entry by that exact name — there's no fuzzy matching or
per-run override today. If a datasource is renamed on the cluster side, the
local connection has to be re-registered under the new name.

## No self-serve engine choice beyond MySQL, PostgreSQL, and Amazon Redshift

Other database engines aren't supported yet. If you need one, ask your syl4
contact — they can tell you where it sits on the roadmap.

## The natural-language write path isn't shipped yet

Today's syl4 is read-only: it answers questions. Natural-language
`UPDATE`/`INSERT`/`DELETE` with previewed row changes before anything
commits is on the roadmap, not available in this release. See
[highlights.md](./highlights.md) for what does ship today.

## `syl4ish` doesn't yet ask a grounded clarifying question

When your prompt is ambiguous, `syl4ish` currently resolves the ambiguity
itself and shows you the reading it picked so you can correct it — it
doesn't yet interrupt with a specific question ("two customers match
_Acme_ — which one?"). That's on the roadmap.

## This repository's issues and pull requests aren't monitored

For help, ask the person who invited you to syl4 — the person who gave you
your cluster address.
