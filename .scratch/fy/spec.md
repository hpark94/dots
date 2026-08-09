# Spec: `fy` - File Reference to Clipboard Script

Status: implemented

## Problem Statement

As a user of this dotfiles repo, I have `fp` to paste files from the clipboard
into my filesystem, but I have no corresponding way to _copy_ a file to the
clipboard so a file manager, `fp`, or a web app can receive the actual file.
This creates an asymmetry in the clipboard workflow: I can get files from the
clipboard, but I cannot put them there.

## Solution

Create a script `fy` that copies a single file _reference_ to the Wayland
clipboard. It emits a `file://` URI in the `text/uri-list` clipboard target,
whose payload is one CRLF-terminated URI:

```
file:///absolute/percent-encoded/path\r\n
```

`fp`, the terminal, and browser chats (Claude web) read this target to receive
the file. `fy` puts a _reference_ on the clipboard, not raw bytes, so the
receiver ends up with the file itself rather than its contents inlined.

### Format tradeoff (deliberate)

`wl-copy` can advertise only ONE custom target per invocation. Empirically, on
the live sway session, browsers paste files only from `text/uri-list`, while
Thunar (and other GTK file managers) paste only from
`x-special/gnome-copied-files`. These cannot be co-advertised. We chose
`text/uri-list` because it covers browser-chat upload, `fp`, and the terminal.
The deliberate cost: a fy-copied file does NOT paste into Thunar (Thunar's own
copy/paste is unaffected). A multi-target helper that could satisfy both was
considered and rejected for complexity. `fp` still reads
`x-special/gnome-copied-files` too, so files copied by a real file manager paste
in via `fp`.

---

## User Stories

1. As a dotfiles user, I want to copy a file reference to the clipboard so that
   I can paste the file into a file manager, `fp`, or a Chromium-based web app.
2. As a dotfiles user, I want `fy` to hand off the file itself, so that pasting
   produces the file, not a blob of its bytes.
3. As a dotfiles user, I want `fy` to work for any file regardless of type
   (image, PDF, text), because a reference carries no bytes and needs no MIME
   detection.
4. As a dotfiles user, I want `fy` to fail with a clear error if the file
   doesn't exist, so that I know what went wrong.
5. As a dotfiles user, I want `fy` to fail with a clear error if `wl-copy` is
   unavailable, so that I don't think I copied something when I didn't.
6. As a dotfiles user, I want `fy` to follow the same conventions as `fp` (error
   handling, tilde-collapsed output), so that the clipboard workflow feels
   consistent.
7. As a dotfiles user, I want `fy` to put a file reference on the clipboard so
   that browser chats and `fp` can receive the actual file, not merely its text
   contents.
8. As a dotfiles user, I want the original filename to survive the copy, which
   it does inherently: the filename is the last segment of the `file://` path.
9. As a dotfiles user, I want `fy` installed alongside `fp` in
   `.local/scripts/`, so that it is discoverable and consistent.
10. As a dotfiles user, I want `fy` to work on both Desktop and Headless roles
    (via `waypipe` for SSH), so that I can use it regardless of where I'm
    working.
11. As a dotfiles user, I want `fy` to handle filenames with spaces or special
    characters, so that the script is robust.
12. As a dotfiles user, I want `fy` to output only the copied file's path on
    stdout, so that it can be chained with other commands if needed.

---

## Implementation Decisions

- **Clipboard Backend**: Use `wl-copy` exclusively, matching `fp`'s use of
  `wl-paste`.
- **Single Clipboard Type**: `wl-copy` (2.2.1) accepts only one `--type` per
  invocation, and a second call replaces the clipboard. `fy` therefore
  advertises exactly one target: `text/uri-list`. See the format tradeoff above
  for why `text/uri-list` over `x-special/gnome-copied-files`.
- **Reference, Not Bytes**: The payload is `file://<uri>\r\n` (CRLF per RFC
  2483, matching what Thunar emits and what browsers accept; `fp` strips the CR
  via `tr -d '\r'`). No file bytes are placed on the clipboard, so there is no
  MIME type to detect and no size to limit.
- **Single File Only**: Exactly one file argument. Zero or more than one
  arguments is an error.
- **Path Encoding**: Resolve to an absolute path with `realpath`, then
  percent-encode into an RFC 3986 `file://` path. Unreserved bytes and the path
  separator stay literal; everything else (including `%`, space, and non-ASCII
  bytes) is percent-encoded. `%` is encoded first to avoid double-encoding. The
  encoding round-trips through `fp`'s `printf '%b' "${uri//%/\\x}"` decoder.
- **Error Handling**:
  - Exit non-zero on any failure (bad arg count, missing file, missing
    `wl-copy`, `wl-copy` failure).
  - Print diagnostics to stderr, never stdout.
- **Success Output**: Echo the tilde-collapsed absolute path as the sole stdout
  line, reusing `fp`'s `print_result` helper.

---

## Testing Decisions

**Test Strategy**: Test `fy` and `fp` at the script boundary, stubbing
`wl-copy`/`wl-paste` on PATH. The `wl-copy` stub records its args and stdin to
files on disk so assertions survive the `run bash "$SCRIPT"` subshell and can
inspect the exact clipboard payload.

**Testing Conventions**:

- **Type of Testing**: Unit testing via BATS. Prior Art: `theme-switch.bats` and
  `bootstrap.bats` in `.local/scripts/tests/`.
- **fy coverage**:
  - Success: one-arg copy writes `text/uri-list` with payload
    `file://<encoded abs path>\r\n`.
  - Success: filename with a space is percent-encoded (`%20`).
  - Success: stdout is the tilde-collapsed path.
  - Error: zero args, more than one arg, non-existent file, `wl-copy` missing,
    `wl-copy` failing.
- **fp coverage**:
  - Reconstructs a file from a `x-special/gnome-copied-files` reference (still
    valid for real file managers).
  - Decodes a percent-encoded space in that reference.
- **Roundtrip**: `fy` writes its `text/uri-list` payload, the captured payload
  feeds `fp`'s stubbed `wl-paste` as `text/uri-list`, and the reconstructed file
  (space in name) matches by checksum.

---

## Out of Scope

- **Multiple Files**: `fy` copies exactly one file. Loop manually for more.
- **Directories**: `fy` will not copy directories (recursively or as archives).
- **Non-Wayland Fallbacks**: If `wl-copy` is unavailable, `fy` errors. xclip,
  xsel, and OSC 52 are Out of Scope.
- **Raw Bytes / MIME Detection**: `fy` copies a reference, not bytes, so MIME
  detection and a size limit do not apply.
- **Thunar paste target**: Pasting a fy-copied file INTO Thunar is out of scope;
  Thunar requires `x-special/gnome-copied-files`, which `wl-copy` cannot
  co-advertise with `text/uri-list`.
- **Image-bytes / LibreOffice mode**: A future `fy -c` that copies raw image
  bytes (for LibreOffice or "paste image" targets) is out of scope for now.
- **Clipboard History**: No interaction with clipboard managers like `cliphist`.
- **GUI Integration**: CLI script only. No tray, notifications, or dialogs.

---

## Further Notes

- Browsers (Claude web) paste files from `text/uri-list`; Thunar and other GTK
  file managers paste from `x-special/gnome-copied-files`. `wl-copy` advertises
  one target, so `fy` picks `text/uri-list` (browser + `fp` + terminal) and
  gives up Thunar paste-in.
- Chromium-based web-app pastes require a live compositor and are verified
  manually (see ticket 05); the automated suite uses a stub-level roundtrip.
- The script follows the repo's shell style: `set -euo pipefail`, clear error
  messages, comments that say WHY.
