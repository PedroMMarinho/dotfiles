#!/usr/bin/env bash
# Loads a Quickshell config in an isolated instance and reports QML errors.
# Exits 0 on a clean load, 1 if anything error-shaped appears in the log.
#
# There is no test framework for this config, and qmllint is unreliable here
# (it exits 255 on baseline files too), so loading the config for real and
# reading the log is the only trustworthy check.
#
# Note: this spawns a *second* bar alongside the running one for a few seconds.
# It stacks below the real bar and disappears when the check finishes.
set -uo pipefail

CONFIG="${1:-$HOME/dotfiles/configs/.config/quickshell/shell.qml}"
SETTLE="${QS_CHECK_SETTLE:-6}"

if [[ ! -f "$CONFIG" ]]; then
  echo "qs-check: no such config: $CONFIG" >&2
  exit 1
fi

LOG="$(mktemp -t qs-check.XXXXXX.log)"
trap 'rm -f "$LOG"' EXIT

# setsid so the child is not in this shell's process group; we kill it by PID.
setsid quickshell -p "$CONFIG" >"$LOG" 2>&1 &
QS_PID=$!

sleep "$SETTLE"
kill "$QS_PID" 2>/dev/null
wait "$QS_PID" 2>/dev/null

# Strip ANSI colour, drop the INFO banner, drop known-benign noise, then look
# for QML-level faults specifically.
#
# Ignored: quickshell.dbus.properties warnings. Some third-party tray items
# (Electron apps) fail to serve org.kde.StatusNotifierItem property Gets, which
# is a long-standing pre-existing condition of this setup and says nothing about
# whether our QML is correct. Filtering on 'error' alone makes the check fail
# permanently, which would make it useless as a pass signal.
ERRORS="$(sed 's/\x1b\[[0-9;]*m//g' "$LOG" \
  | grep -vE '^\s*INFO' \
  | grep -vE 'quickshell\.dbus\.properties' \
  | grep -vE 'QDBusError' \
  | grep -iE 'ReferenceError|TypeError|SyntaxError|is not defined|is not a (type|function|component)|Unable to assign|Cannot assign|no such property|not a valid identifier|file:.*\.qml:[0-9]+|Failed to (load|compile|create)')"

if [[ -n "$ERRORS" ]]; then
  echo "qs-check: FAIL — $CONFIG"
  echo "$ERRORS"
  exit 1
fi

echo "qs-check: OK — $CONFIG loaded clean"
exit 0
