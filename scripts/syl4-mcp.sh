#!/bin/sh
# MCP launcher for the syl4 plugin. Claude Code runs this to start the
# plugin's `syl4` MCP server; it reads the gateway address that
# `syl4 setup` stored and proxies stdio MCP to the gateway's
# streamable-HTTP endpoint. Resolving the address here, at connect
# time, is what lets a static plugin config serve a server chosen
# during install — and lets `/reload-plugins` connect it in the same
# session that ran setup.

CONFIG="$HOME/.syl4/config.json"

# Line-based extraction works on both compact and indented JSON, and
# `addr` appears exactly once in the file syl4 writes.
ADDR=$(sed -n 's/.*"addr"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null | head -n 1)
if [ -z "$ADDR" ]; then
    echo "syl4 is not set up yet (no address in $CONFIG) — run /syl4:install first" >&2
    exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
    echo "npx not found — the syl4 MCP proxy needs Node.js (https://nodejs.org)" >&2
    exit 1
fi

# mcp-remote bridges stdio to streamable HTTP and performs the
# MCP-standard OAuth flow against the gateway on first connect.
exec npx -y mcp-remote "${ADDR%/}/mcp"
