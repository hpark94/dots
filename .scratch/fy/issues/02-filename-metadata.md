# 02 — Filename Metadata Preservation

**What to build:** Extend `fy` to attempt preserving the original filename in the clipboard metadata using the `x-special/nautilus-clipboard` format. If this format is unsupported by the compositor, the script should fall back to copying raw bytes with MIME type only (already implemented in ticket 01).

**Blocked by:** 01 — Core fy Script

**Status:** ready-for-agent

- [ ] `fy` attempts to include filename using `x-special/nautilus-clipboard` format
- [ ] Falls back gracefully to raw bytes + MIME type if metadata format fails
- [ ] No change to existing success/error behavior from ticket 01