# 01 — Core fy Script

**What to build:** A minimal `fy` script in `.local/scripts/fy` that copies a single file's contents to the Wayland clipboard using `wl-copy` with MIME type detection via `file --mime-type`, and outputs the user-friendly path on success. It should fail with clear errors for non-existent files, unavailable clipboard, or multiple arguments.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] Script exists at `.local/scripts/fy` and is executable
- [ ] Accepts exactly one file argument; errors with clear message on 0 or >1 args
- [ ] Detects MIME type using `file --mime-type`
- [ ] Falls back to file extension heuristics if `file` fails
- [ ] Copies raw file bytes to clipboard via `wl-copy` with detected MIME type
- [ ] Outputs user-friendly path (tilde-expanded) on stdout
- [ ] Errors with clear message to stderr if file doesn't exist
- [ ] Errors with clear message to stderr if clipboard is unavailable
- [ ] Follows repo shell style: `set -euo pipefail`, no unnecessary subshells