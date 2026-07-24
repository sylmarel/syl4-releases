#!/bin/sh
# SessionStart hook: while syl4 is not set up on this machine, nudge
# the session to offer onboarding. Installing a plugin runs nothing by
# itself — this hook is what turns "plugin installed" into "the next
# session offers to set syl4 up". Its stdout becomes session context;
# once setup has stored a config it prints nothing and the nudge
# disappears.
[ -f "$HOME/.syl4/config.json" ] && exit 0
cat <<'EOF'
The syl4 plugin is installed, but syl4 is not set up on this machine
yet (~/.syl4/config.json does not exist). At the first natural moment
— immediately if the user has no other request — offer to set it up
by running the /syl4:install skill: it asks which server to connect
to (default: demo), downloads the syl4 CLI, runs `syl4 setup`, and
connects the syl4 MCP server. If the user declines, drop the subject
for the rest of the session.
EOF
