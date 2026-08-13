# 05: Roundtrip Integration Test

**What to build:** Verify the end-to-end workflow: `fy <file>` puts a reference
on the clipboard, and the file can then be pasted back out. Cover it
automatically at the stub level, and document the live-compositor pastes that
must be checked manually.

**Blocked by:** 01, Core fy Script, 04, BATS Test Suite

**Status:** done

- [x] Automated stub roundtrip: `fy` writes its `text/uri-list` payload, the
      captured payload feeds `fp`'s stubbed `wl-paste`, and the reconstructed
      file matches by checksum (in `fp.bats`)
- [x] Automated roundtrip covers a filename with a space to prove encode/decode
- [x] Manual (live compositor): `fy` a file, then `fp` in a different directory
      reproduces it, checksum matches
- [x] Manual (live compositor): `fy` a file, then paste into a Chromium-based
      web chat (Claude web) attaches the file

## Manual verification notes

The stub roundtrip proves the payload format and the fy->fp decode path without
a compositor. The live fy->fp roundtrip was verified on the sway session
(checksum match, space-in-name file). The following requires a live Wayland
session plus a GUI browser and is checked by hand:

- **Chromium-based web chat**: `fy somefile`, then paste into a chat's file
  attachment. The browser reads `text/uri-list` and uploads the file.

Pasting a fy-copied file INTO Thunar is intentionally NOT supported: Thunar
needs `x-special/gnome-copied-files`, which `wl-copy` cannot co-advertise with
`text/uri-list`. This path is out of scope, not a pending test.
