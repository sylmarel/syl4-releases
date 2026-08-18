# syl4 CLI

`syl4` is the command-line half of syl4: it runs on your own machine, next to your data. You work in Claude
Code, syl4 turns your prompt into a program, and this client runs that program locally in a container. The
cluster sees your prompt and your database's schema; your rows and the program's results stay on your machine,
and the cluster is told only whether a run succeeded. Instead of guessing at SQL, syl4 compiles your question
into a typed, formally verified program and derives the SQL from that — the same answer, provably, every time.

## Quick start

```sh
curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh | sh
```

Full prerequisites, setup, connecting your data, and asking your first question are in
[`docs/install.md`](docs/install.md).

## Documentation

- **[Install](docs/install.md)** — prerequisites, the install script, verifying what you downloaded,
  one-time setup, connecting a datasource, and asking your first question.
- **[Troubleshooting](docs/troubleshooting.md)** — common errors and how to fix them.
- **[Known issues](docs/known-issues.md)** — current limitations worth knowing before you hit them.
- **[Highlights](docs/highlights.md)** — why syl4 for text-to-SQL: confirmed interpretations, cached plans,
  your own vocabulary as reviewed definitions, and the exact SQL on demand.

## About this repository

It holds published releases, the two files the script install flow needs — `install.sh` and this page — and
the Claude Code plugin (`.claude-plugin/`, `skills/`, and `scripts/`). syl4's source repository is private, and
`curl` cannot download from a private repository, which is why the releases live here. `install.sh` and this
page are written and reviewed in the source repository and overwritten here on every release, so edits made
here directly would not survive — the `docs/` folder is maintained in this repository directly. Issues and
pull requests are not monitored — for help, ask your syl4 contact, the person who gave you your cluster
address.
