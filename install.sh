#!/bin/sh
# Install the syl4 CLI.
#
#   curl -fsSL https://raw.githubusercontent.com/sylmarel/syl4-releases/main/install.sh | sh
#
# What it does, and why it is safe to run:
#   - POSIX sh only, with no dependencies beyond curl and a sha256 tool,
#     both present on a stock macOS or Linux box.
#   - Everything runs from main(), called on the last line, so a download
#     cut short by a dropped connection executes nothing.
#   - The binary is checked against the release's SHA256SUMS before it is
#     made executable, so a corrupt or truncated download never runs. That
#     detects a damaged download, not a substituted one — SHA256SUMS comes
#     from the same place as the binary. Provenance is the check for that.
#   - It downloads the provenance bundle and prints the command to verify
#     it, but never runs that check itself: a script fetched alongside the
#     binary cannot vouch for the binary, and verifying needs gh, which a
#     stock box does not have.
#   - curl sets no com.apple.quarantine, so macOS needs no xattr step.
#   - Installs to ~/.syl4/bin (no sudo) by default.
#
# Environment overrides:
#   SYL4_VERSION      release tag to install (e.g. v0.0.1); default: latest
#   SYL4_INSTALL_DIR  install directory; default: ~/.syl4/bin
#   SYL4_SHOW_VERIFY  =1 to also print the provenance-verify command after
#                     installing; default: off (the bundle is saved either way)

set -u

# Single-quote a value for copy-paste into a shell. The commands this
# script prints are meant to be pasted and run, and an install dir with a
# space in it otherwise emits a line that silently parses as extra
# arguments — worst of all for the verify command, where the user would
# conclude verification is broken rather than that the path was unquoted.
shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# Detail lines after the first are indented under it, so a multi-line
# error still reads as one message. Passing them as separate arguments
# rather than embedding newlines in one string also keeps this file free
# of column-0 string continuations, which would read as top-level code.
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
    SOURCE_REPO="sylmarel/sylpy"
    SIGNER_WORKFLOW="$SOURCE_REPO/.github/workflows/cli-release.yml"
    BUNDLE="syl4.attestation.jsonl"
    # HOME is not guaranteed (service managers, minimal containers, cron).
    # Naming the override beats `set -u` aborting with a bare line number.
    if [ -z "${SYL4_INSTALL_DIR:-}" ] && [ -z "${HOME:-}" ]; then
        fail "HOME is not set — pass SYL4_INSTALL_DIR=<dir> to choose where to install"
    fi
    INSTALL_DIR="${SYL4_INSTALL_DIR:-$HOME/.syl4/bin}"
    VERSION="${SYL4_VERSION:-}"
    # Provenance verification is opt-in. It is an advanced step — the how-to
    # is on the release page and in the repo README — and printing it after
    # the setup command clutters the path everyone actually takes. The bundle
    # is still saved either way (see below); SYL4_SHOW_VERIFY=1 also prints
    # the verify command here.
    case "${SYL4_SHOW_VERIFY:-}" in
        1 | true | yes | on) show_verify=1 ;;
        *) show_verify=0 ;;
    esac

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

    # Staging now happens inside $INSTALL_DIR (so the executable bit is set
    # on a file that is already on the destination filesystem), which puts
    # it outside $tmp and therefore outside the old trap. Clean both, cover
    # HUP as well as INT/TERM, and exit non-zero on a signal: without the
    # explicit exit the trap returns and the script carries on with a
    # deleted temp dir, reporting a successful install and exit 0.
    staged=""
    staged_bundle=""
    cleanup() {
        rm -rf "$tmp"
        [ -n "$staged" ] && rm -f "$staged"
        [ -n "$staged_bundle" ] && rm -f "$staged_bundle"
        return 0
    }
    trap cleanup EXIT
    trap 'cleanup; exit 130' INT TERM HUP

    echo "Downloading $asset (${VERSION:-latest})..."
    curl -fsSL --proto '=https' -o "$tmp/$asset" "$base/$asset" \
        || fail "download failed: $base/$asset"
    curl -fsSL --proto '=https' -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" \
        || fail "download failed: $base/SHA256SUMS"

    # The provenance bundle, from the SAME base URL as the binary so it is
    # pinned to the release actually installed: `latest` moves, and a bundle
    # fetched later from a newer release does not cover this binary's digest
    # — verification would then fail on a perfectly good install.
    #
    # Non-fatal: a release predating the bundle, or a blip fetching it, must
    # not sink an install whose binary already checksum-verified.
    #
    # "absent" and "could not fetch" are reported differently on purpose. A
    # network attacker who cannot break TLS CAN still reset this one
    # connection, and answering that with "no bundle published" would state,
    # as fact, that there is nothing to verify — quietly retiring the only
    # check that survives a release compromise.
    #
    # Branch on the HTTP status, not on curl's exit code. curl's code for a
    # 404 depends on the negotiated protocol — GitHub over HTTP/2 exits 56,
    # the same URL forced to HTTP/1.1 exits 22 — so an exit-code test both
    # misses real 404s and lumps 403/407/5xx in with them. Hence -w rather
    # than -f here.
    have_bundle=0
    bundle_status=missing
    bundle_code="$(curl -sSL --proto '=https' -o "$tmp/$BUNDLE" \
        -w '%{http_code}' "$base/$BUNDLE" 2>/dev/null || true)"
    case "${bundle_code:-000}" in
        200) have_bundle=1 ;;
        404) bundle_status=missing ;;
        *) bundle_status=fetch_failed ;;
    esac
    # Without -f, a non-200 leaves the error body in the file.
    [ "$have_bundle" = 1 ] || rm -f "$tmp/$BUNDLE"

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
    # Staged inside the destination directory, then renamed. `mv` across
    # filesystems degrades to copy-then-unlink, and TMPDIR on tmpfs with
    # $HOME on disk is the common Linux layout — so a copy interrupted by a
    # full disk or a quota would leave a truncated file that chmod had
    # already made executable, breaking the guarantee above. A same-directory
    # rename is atomic, and also replaces a running binary safely.
    mkdir -p "$INSTALL_DIR" || fail "cannot create $INSTALL_DIR"
    staged="$INSTALL_DIR/.syl4.incoming.$$"
    if ! cp "$tmp/$asset" "$staged"; then
        fail "cannot write to $INSTALL_DIR"
    fi
    chmod +x "$staged"
    mv -f "$staged" "$INSTALL_DIR/syl4" || fail "cannot install to $INSTALL_DIR"
    staged=""
    if [ "$have_bundle" = 1 ]; then
        staged_bundle="$INSTALL_DIR/$BUNDLE.incoming.$$"
        if cp "$tmp/$BUNDLE" "$staged_bundle" \
            && mv -f "$staged_bundle" "$INSTALL_DIR/$BUNDLE"; then
            staged_bundle=""
        else
            # Distinct from fetch_failed: the download succeeded and it is
            # the local save that failed, so "retry the download" would be
            # the wrong advice.
            rm -f "$staged_bundle"
            staged_bundle=""
            have_bundle=0
            bundle_status=save_failed
        fi
    fi

    installed_version="$("$INSTALL_DIR/syl4" version 2>/dev/null)"
    echo "Installed syl4 ${installed_version:-(version unknown)} to $INSTALL_DIR/syl4"

    # The next command comes before the optional security block: almost
    # everyone wants it, and burying it under eight lines of provenance text
    # is how it gets missed. `syl4 setup` needs the cluster address from the
    # invite — without it the command exits non-zero, so naming it bare
    # would send every first-time user straight into an error.
    setup_cmd="syl4 setup"
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *)
            setup_cmd="$(shell_quote "$INSTALL_DIR/syl4") setup"
            # Both HOME and SHELL are dereferenced defensively: `set -u` is
            # on, and neither is guaranteed (dash does not set SHELL, and a
            # container or service manager may set neither). Getting this
            # wrong aborts AFTER a successful install, taking the next-step
            # and provenance output with it. Anything we cannot place
            # confidently — fish, ksh, no SHELL, no HOME — gets the
            # shell-agnostic line rather than one aimed at the wrong file.
            rc_file=""
            rc_shell=""
            if [ -n "${HOME:-}" ]; then
                rc_shell_name="${SHELL:-}"
                case "${rc_shell_name##*/}" in
                    bash) rc_file="$HOME/.bashrc"; rc_shell=bash ;;
                    zsh) rc_file="$HOME/.zshrc"; rc_shell=zsh ;;
                    *) ;;
                esac
            fi
            # $PATH stays literal in the emitted text: it is expanded when
            # the startup file is read, not now.
            path_line="export PATH=\"$INSTALL_DIR:\$PATH\""
            echo ""
            echo "$INSTALL_DIR is not on your PATH."
            if [ -n "$rc_file" ]; then
                echo "Add it with:"
                echo ""
                echo "  echo $(shell_quote "$path_line") >> $(shell_quote "$rc_file") && exec $rc_shell"
            else
                echo "Add this line to your shell's startup file:"
                echo ""
                echo "  $path_line"
            fi
            ;;
    esac

    echo ""
    echo "Next: connect to your cluster, using the address from your invite:"
    echo ""
    echo "  SYL4_ADDR=<your cluster address> $setup_cmd"

    # Opt-in (SYL4_SHOW_VERIFY); the common path ends at the setup step
    # above. When shown, this is printed, never performed: the script
    # arrives with the download, so a self-check proves nothing — whoever
    # could swap the binary could delete these lines or point
    # --signer-workflow at something of their own and still print
    # "verified". The identity is deliberately NOT sourced from here or any
    # page this script could name; the person who invited the user is
    # outside that blast radius.
    [ "$show_verify" = 1 ] || return 0
    if [ "$have_bundle" = 1 ]; then
        echo ""
        echo "A signature file was saved to $INSTALL_DIR/$BUNDLE."
        echo "The installer did not check it — a check that arrives with the"
        echo "download cannot vouch for the download. To verify it yourself"
        echo "(needs GitHub's gh CLI, but no GitHub account):"
        echo ""
        echo "  gh attestation verify $(shell_quote "$INSTALL_DIR/syl4") \\"
        echo "    --bundle $(shell_quote "$INSTALL_DIR/$BUNDLE") \\"
        echo "    --repo $SOURCE_REPO --signer-workflow $SIGNER_WORKFLOW"
        echo ""
        echo "Those last two values are what make the check mean anything,"
        echo "and this output cannot vouch for them either. Ask whoever"
        echo "invited you to syl4 to send you that command, and run theirs."
        echo "If the check fails, do not run the binary — tell them."
    elif [ "$bundle_status" = fetch_failed ]; then
        echo ""
        echo "Could not download the signature file for this release, so there"
        echo "was nothing to save. This is a download failure, not a missing"
        echo "signature. To retry:"
        echo ""
        echo "  curl -fsSLO --proto '=https' $base/$BUNDLE"
    elif [ "$bundle_status" = save_failed ]; then
        echo ""
        echo "The signature file downloaded but could not be saved to"
        echo "$INSTALL_DIR. The binary is installed; re-run the installer to"
        echo "retry, or fetch the signature yourself:"
        echo ""
        echo "  curl -fsSLO --proto '=https' $base/$BUNDLE"
    else
        echo ""
        echo "This release has no signature file, so there is nothing to verify."
    fi
}

main "$@"
