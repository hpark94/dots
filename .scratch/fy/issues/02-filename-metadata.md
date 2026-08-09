# 02: Filename Metadata Preservation

**What to build:** (Obsolete, satisfied by 01.) The original filename is
inherent in the `file://` path that ticket 01 emits: it is the last path
segment, so the receiver reconstructs the file under its real name with no
separate metadata target. The earlier `x-special/nautilus-clipboard` raw-bytes
approach no longer applies now that `fy` copies a reference, not bytes.

**Blocked by:** 01, Core fy Script

**Status:** obsolete, implemented by reference in 01

- [x] Filename preserved via the `file://` path segment (no separate metadata
      target needed)
