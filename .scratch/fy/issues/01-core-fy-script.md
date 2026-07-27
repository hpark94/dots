# 01 — Core fy Script

**What to build:** A minimal `fy` script in `.local/scripts/fy` that copies a single file *reference* to the Wayland clipboard. It emits a `file://` URI in the `text/uri-list` target (payload `file://<uri>\r\n`) via `wl-copy`, and outputs the tilde-collapsed path on success. It fails with clear errors for non-existent files, unavailable clipboard, or a wrong argument count. `text/uri-list` is chosen over `x-special/gnome-copied-files` so browser chats and `fp` receive the file; the cost is that pasting into Thunar is not supported (wl-copy advertises one target).

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] Script exists at `.local/scripts/fy` and is executable
- [ ] Accepts exactly one file argument; errors with clear message on 0 or >1 args
- [ ] Resolves the file to an absolute path via `realpath`
- [ ] Percent-encodes the path so it round-trips through fp's decoder (`%` first, then space and other non-unreserved bytes)
- [ ] Emits only `text/uri-list` with payload `file://<encoded abs path>\r\n` via `wl-copy`
- [ ] Outputs tilde-collapsed path on stdout
- [ ] Errors with clear message to stderr if the file doesn't exist
- [ ] Errors with clear message to stderr if `wl-copy` is unavailable or fails
- [ ] Follows repo shell style: `set -euo pipefail`, no unnecessary subshells
