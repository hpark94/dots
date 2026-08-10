#!/usr/bin/env bash
set -euo pipefail

# The same ownership test .local/scripts/caffeine applies, so the icon tracks the
# toggle rather than any inhibitor on the machine: a package manager holding one
# of its own must not light this up.
pid=""
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    pid=$(cat "${XDG_RUNTIME_DIR}/caffeine.pid" 2>/dev/null || true)
fi

if [[ -n "${pid}" && -r "/proc/${pid}/comm" ]] \
    && [[ "$(cat "/proc/${pid}/comm")" == "systemd-inhibit" ]]; then
    echo '{"text": "󰅶", "class": "active", "tooltip": "Caffeine on: standby blocked"}'
else
    echo '{"text": "󰾪", "class": "inactive", "tooltip": "Caffeine off"}'
fi
