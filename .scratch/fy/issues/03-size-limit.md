# 03 — File Size Limit

**What to build:** Add a 25MB size check to `fy`. If the file exceeds this limit, the script should fail with a clear error message before attempting to copy.

**Blocked by:** 01 — Core fy Script

**Status:** ready-for-agent

- [ ] `fy` checks file size before copying
- [ ] Errors with clear message to stderr if file exceeds 25MB
- [ ] Size limit is configurable via a variable at the top of the script
- [ ] Uses efficient check (stat, not reading entire file)