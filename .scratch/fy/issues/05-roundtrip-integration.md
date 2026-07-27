# 05 — Roundtrip Integration Test

**What to build:** An integration test that verifies the end-to-end workflow: `fy file` followed by `fp` reproduces the original file. This should be a manual verification step or a separate BATS test that requires a working Wayland clipboard.

**Blocked by:** 01 — Core fy Script, 04 — BATS Test Suite for fy

**Status:** ready-for-agent

- [ ] Manual verification: `fy` a test file, then `fp` in a different directory reproduces the file
- [ ] Test with text file
- [ ] Test with binary file (e.g., PNG image)
- [ ] Test that file contents match exactly (checksum comparison)
- [ ] Document as a manual test in the spec if automated testing is not feasible