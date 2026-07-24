# syl4 CLI

`syl4` is the command-line half of syl4: it runs on your own machine, next to your data. You work in Claude
Code, syl4 turns your prompt into a program, and this client runs that program locally in a container. The
cluster sees your prompt and your database's schema; your rows and the program's results stay on your machine,
and the cluster is told only whether a run succeeded.

## Install as a Claude Code plugin

If you work in Claude Code, the plugin in this repository wraps the whole flow — download, `syl4 setup`, and
sign-in — into one guided run. In Claude Code:

```text
/plugin marketplace add sylmarel/syl4-releases
/plugin install syl4@syl4
```

Then start `/syl4:install` (or just ask to "install syl4"). It downloads the binary with the same
checksum-verified installer described below, asks which server domain to connect to (default: `demo`, for
`demo.sylfor.ai` — a bare name is qualified with `sylfor.ai`), runs `syl4 setup`, and signs you in to the
server. The plugin ships the syl4 MCP server itself, so `/reload-plugins` connects it right after install —
no session restart. The proxy it starts needs Node.js (`npx`) on `PATH`.

The script install below is unchanged and remains the way to install for opencode and other harnesses.

## Install with the script

```sh
curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh | sh
```

That picks the right binary for your machine, checks the download arrived intact, and installs it to
`~/.syl4/bin/syl4`. No `sudo`, and none of the security prompts a macOS browser download triggers.

`~/.syl4/bin` is usually not on your `PATH`. The installer prints the one line that adds it; until you run
that, use the full path — `~/.syl4/bin/syl4` — wherever these instructions say `syl4`.

Then connect it to your cluster, using the address you were given when you were invited:

```sh
SYL4_ADDR=<your cluster address> syl4 setup
```

Setup expects two things to be installed already:

- a container engine that is **running** — Docker, Podman, or nerdctl
- [Claude Code](https://claude.com/claude-code), which is how you talk to syl4

It checks both before changing anything, so a missing one is named and nothing is left half-installed. When
setup finishes, open Claude Code and start a syl4 prompt.

### Options

To pin a version, or install somewhere other than `~/.syl4/bin`:

```sh
curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh \
  | SYL4_VERSION=v0.0.1 SYL4_INSTALL_DIR=~/bin sh
```

Both settings must go **after** the `|`, in front of `sh`. In front of `curl` they are silently ignored and
you get a default install. The install directory has to be one you can write to without `sudo`.

Windows has no install script — download `syl4-windows-<arch>.exe` from the
[releases page](https://github.com/sylmarel/syl4-releases/releases). To remove syl4, run `syl4 unregister`,
then delete `~/.syl4`.

## Verifying what you downloaded

The installer prints `Checksum verified.` before installing. Read that narrowly: the checksum file ships
alongside the binary, so it shows your download arrived intact — not that the right file was published.

The stronger check is optional and you run it yourself. It needs [GitHub's `gh` CLI](https://cli.github.com/),
though not a GitHub account. The installer saves a signature file beside the binary, so after installing:

```sh
gh attestation verify ~/.syl4/bin/syl4 \
  --bundle ~/.syl4/bin/syl4.attestation.jsonl \
  --repo sylmarel/sylpy \
  --signer-workflow sylmarel/sylpy/.github/workflows/cli-release.yml
```

A pass means those exact bytes came out of syl4's release pipeline. **If it fails, do not run the binary —
tell your syl4 contact.** For a binary you downloaded by hand, the same signature file is on the
[releases page](https://github.com/sylmarel/syl4-releases/releases) — point `--bundle` at your copy; the same
command also verifies `SHA256SUMS`. On a restricted network it needs to reach `tuf-repo.github.com` and
`tuf-repo-cdn.sigstore.dev`.

Installing with `SYL4_SHOW_VERIFY=1` set makes the installer print this command for you, filled in with your
paths.

The installer never runs this check itself: it arrives with the download, so anyone able to replace the binary
could equally delete the check.

### Where the `--repo` and `--signer-workflow` values come from

Those two values are what make the check worth running. A signature on its own proves only that _some_ build
pipeline produced the file — anyone can sign their own file from their own project, and `--repo` on its own
accepts any workflow in the named repository. Naming both the project and the exact workflow is what ties the
download to us.

So they have to reach you from somewhere other than the download — and this page is not it. It is served from
the same repository as the binaries, so anyone who could swap a binary here could edit these lines too.

Ask the person who invited you to syl4 to send you the verify command, and run the one they send. If it does
not match the one above, stop and tell them. Today that is the only route to these values we do not also
control; publishing them on a syl4-owned domain is what will remove the need to ask, and that is not done yet.

## About this repository

It holds published releases, the two files the script install flow needs — `install.sh` and this page — and
the Claude Code plugin (`.claude-plugin/`, `skills/`, and `scripts/`). syl4's
source repository is private, and `curl` cannot download from a private repository, which is why the releases
live here. Both files are written and reviewed in the source repository and overwritten here on every release,
so edits made here would not survive. Issues and pull requests are not monitored — for help, ask your syl4
contact, the person who gave you your cluster address.
