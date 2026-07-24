# syl4 CLI

Release distribution for the `syl4` command-line client. The binaries here are built by CI in syl4's source
repository (`sylmarel/sylpy`, private); this repository exists to host them publicly, because a release asset
behind private-repo authentication cannot be fetched with a plain `curl`.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh | sh
```

Detects your OS and architecture, downloads the matching binary plus `SHA256SUMS`, verifies the checksum before
making the file executable, and installs to `~/.syl4/bin/syl4`. No sudo required, and no macOS `xattr` step —
`curl` does not set `com.apple.quarantine` the way a browser download does.

Then run `syl4 setup` to configure the container engine, gateway address, and Claude Code integration.

- `SYL4_VERSION=v0.0.1` installs a specific release instead of the latest.
- `SYL4_INSTALL_DIR=/usr/local/bin` installs somewhere other than `~/.syl4/bin`.
- Windows has no install script — download `syl4-windows-<arch>.exe` from the
  [releases page](https://github.com/sylmarel/syl4-releases/releases).

## Verifying what you downloaded

Every release ships `syl4.attestation.jsonl`, a [Sigstore](https://www.sigstore.dev/) bundle covering all six
binaries. Verifying it requires no GitHub account:

```sh
curl -fsSLO https://github.com/sylmarel/syl4-releases/releases/latest/download/syl4.attestation.jsonl
gh attestation verify syl4-darwin-arm64 \
  --bundle syl4.attestation.jsonl --repo sylmarel/sylpy
```

That proves these exact bytes were produced by syl4's build workflow from a specific source commit.

`--repo sylmarel/sylpy` is the part that carries the guarantee. The signature on its own only proves that _some_
workflow built the file — anyone can obtain a valid signature for their own file from their own repository — so
it is the identity you pin that ties the download to this project. Verification reaches
`tuf-repo.github.com` and `tuf-repo-cdn.sigstore.dev` for trust material; allow those two if your network
restricts outbound traffic.

`SHA256SUMS`, which the installer checks automatically, is a weaker and different guarantee: it is served from
the same release as the binaries, so it detects a corrupted or truncated download but not a substituted one.

## About this repository

It holds published artifacts only. `install.sh` and this README are generated from the source repository and
overwritten on every release — they should be changed there, not here. Issues and pull requests are not tracked
in this repository.
