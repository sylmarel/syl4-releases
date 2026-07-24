#!/bin/sh
# Install the syl4 CLI from the public release repo (#773).
#
#   curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh | sh
#
# Source of truth is cli/install.sh in the sylpy monorepo; cli-release.yml
# syncs it to syl4-releases/main on every publish. Design constraints:
#   - POSIX sh only: must run under a bare `| sh` on a fresh macOS or
#     Linux box (no bash-isms, no external deps beyond curl + a sha256
#     tool, both present on stock macOS and every mainstream distro).
#   - Everything executable lives in main(), invoked on the LAST line.
#     `sh` reads a pipe incrementally and runs what it has, so a dropped
#     connection mid-download otherwise executes a prefix of the script.
#     The statement order here happens to make that survivable (the
#     install comes after the checksum gate, so a prefix either does
#     nothing or finishes a verified install), but the wrapper makes a
#     truncated fetch a strict no-op instead — the guarantee no longer
#     rests on nobody ever reordering these steps.
#   - The binary's checksum is verified against the release's SHA256SUMS
#     BEFORE chmod +x, so a download that arrived corrupt or truncated
#     never becomes executable.
#     This is NOT a tamper defense and must not be described as one:
#     SHA256SUMS ships from the same release as the binary, so anyone
#     able to replace one can replace both. Provenance is the check that
#     survives that, and it lives outside this script —
#       gh attestation verify <binary> \
#         --bundle syl4.attestation.jsonl --repo sylmarel/sylpy
#     (see cli/README.md). Verifying it here would mean depending on gh,
#     which this script deliberately does not.
#   - curl does not set com.apple.quarantine, so no xattr step is
#     needed on macOS (the browser-download friction this replaces).
#   - Installs to a no-sudo location, ~/.syl4/bin by default.
#
# Environment overrides:
#   SYL4_VERSION      release tag to install (e.g. v0.0.1); default: latest
#   SYL4_INSTALL_DIR  install directory; default: ~/.syl4/bin

set -u

# Detail lines after the first are indented under it, so a multi-line
# error still reads as one message. Passing them as separate arguments
# (rather than embedding newlines in one string) also keeps this file
# free of column-0 string continuations — which is what lets the
# truncation guard in tests/scripts/test_install_sh.py stay a simple
# "nothing outside main() does anything" check.
fail() {
    echo "install.sh: error: $1" >&2
    shift
    for detail in "$@"; do
        echo "  $detail" >&2
    done
    exit 1
}

main() {
    REPO="sylmarel/syl4-releases"
    INSTALL_DIR="${SYL4_INSTALL_DIR:-$HOME/.syl4/bin}"
    VERSION="${SYL4_VERSION:-}"

    # --- platform detection ----------------------------------------------
    os="$(uname -s)"
    case "$os" in
        Darwin) os=darwin ;;
        Linux) os=linux ;;
        *)
            fail "unsupported OS '$os' — download a binary manually from https://github.com/$REPO/releases (Windows builds are published as syl4-windows-*.exe)"
            ;;
    esac

    arch="$(uname -m)"
    case "$arch" in
        x86_64 | amd64) arch=amd64 ;;
        arm64 | aarch64) arch=arm64 ;;
        *) fail "unsupported architecture '$arch' — see https://github.com/$REPO/releases for the platforms syl4 ships for" ;;
    esac

    asset="syl4-$os-$arch"

    # --- sha256 tool (macOS ships shasum, Linux ships sha256sum) ---------
    if command -v sha256sum >/dev/null 2>&1; then
        sha256() { sha256sum "$1"; }
    elif command -v shasum >/dev/null 2>&1; then
        sha256() { shasum -a 256 "$1"; }
    else
        fail "need sha256sum or shasum to verify the download"
    fi

    command -v curl >/dev/null 2>&1 || fail "curl is required"

    # --- download --------------------------------------------------------
    if [ -n "$VERSION" ]; then
        base="https://github.com/$REPO/releases/download/$VERSION"
    else
        base="https://github.com/$REPO/releases/latest/download"
    fi

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/syl4-install.XXXXXX")" || fail "mktemp failed"
    trap 'rm -rf "$tmp"' EXIT INT TERM

    echo "Downloading $asset (${VERSION:-latest})..."
    curl -fsSL --proto '=https' -o "$tmp/$asset" "$base/$asset" \
        || fail "download failed: $base/$asset"
    curl -fsSL --proto '=https' -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" \
        || fail "download failed: $base/SHA256SUMS"

    # --- verify before making executable ---------------------------------
    want="$(awk -v a="$asset" '$2 == a { print $1 }' "$tmp/SHA256SUMS")"
    [ -n "$want" ] || fail "$asset not listed in SHA256SUMS"
    got="$(sha256 "$tmp/$asset" | awk '{ print $1 }')"
    [ "$got" = "$want" ] || fail "checksum mismatch for $asset" \
        "expected: $want" \
        "got:      $got" \
        "The download may be corrupt or tampered with; nothing was installed."
    echo "Checksum verified."

    # --- install ----------------------------------------------------------
    mkdir -p "$INSTALL_DIR" || fail "cannot create $INSTALL_DIR"
    chmod +x "$tmp/$asset"
    mv -f "$tmp/$asset" "$INSTALL_DIR/syl4" || fail "cannot install to $INSTALL_DIR"

    echo "Installed $("$INSTALL_DIR/syl4" version 2>/dev/null || echo syl4) to $INSTALL_DIR/syl4"

    # A fresh binary is not usable until `syl4 setup` has validated the
    # container engine and registered the MCP server + skill, so name it
    # as the next step — spelled with the full path when the install dir
    # is not on PATH, so the line is copy-pasteable either way.
    setup_cmd="syl4 setup"
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *)
            setup_cmd="$INSTALL_DIR/syl4 setup"
            echo ""
            echo "$INSTALL_DIR is not on your PATH. Add it with:"
            echo ""
            echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc && exec zsh"
            ;;
    esac

    echo ""
    echo "Next: $setup_cmd"
}

main "$@"
