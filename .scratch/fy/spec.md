# Spec: `fy` - File to Clipboard Copy Script

Status: ready-for-agent

## Problem Statement

As a user of this dotfiles repo, I have `fp` to paste files from the clipboard into my filesystem, but I have no corresponding way to *copy* files to the clipboard for pasting into file managers, browsers, or other applications. This creates an asymmetry in the clipboard workflow: I can get files from the clipboard, but I cannot put them there.

## Solution

Create a new script `fy` that copies a single file's contents to the Wayland clipboard with the correct MIME type, mirroring the behavior of `fp` in reverse. The script will use `wl-copy` with MIME type detection via `file --mime-type`, preserving the same Session Fact awareness as the rest of the repo (failing gracefully when no Wayland clipboard is available).

---

## User Stories

1. As a dotfiles user, I want to copy a file to the clipboard so that I can paste it into a file manager, browser, or document editor.
2. As a dotfiles user, I want `fy` to auto-detect the MIME type of the file I'm copying, so that the receiving application knows how to handle it.
3. As a dotfiles user, I want `fy` to work with binary files (images, PDFs, etc.), so that I can paste them into applications like LibreOffice or chat interfaces.
4. As a dotfiles user, I want `fy` to fail with a clear error if the file doesn't exist, so that I know what went wrong.
5. As a dotfiles user, I want `fy` to fail with a clear error if the file is too large for the clipboard, so that I don't silently lose data.
6. As a dotfiles user, I want `fy` to follow the same conventions as `fp` (e.g., Session Fact awareness, error handling), so that the clipboard workflow feels consistent.
7. As a dotfiles user, I want `fy` to copy only the file contents (not the path) by default, so that pasting works seamlessly in applications.
8. As a dotfiles user, I want `fy` to attempt preserving the filename in the clipboard metadata (if the receiving app supports it), so that pasting retains context.
9. As a dotfiles user, I want `fy` to be installed in the same location as `fp` (`.local/scripts/`), so that it is discoverable and consistent.
10. As a dotfiles user, I want `fy` to work on both Desktop and Headless roles (via `waypipe` for SSH), so that I can use it regardless of where I'm working.
11. As a dotfiles user, I want `fy` to handle edge cases like files with spaces or special characters in their names, so that the script is robust.
12. As a dotfiles user, I want `fy` to output only the copied file's path (or success message) on stdout, so that it can be chained with other commands if needed.

---

## Implementation Decisions

- **Clipboard Backend**: Use `wl-copy` exclusively, matching `fp`'s use of `wl-paste`. This respects the repo's Session Fact (`$WAYLAND_DISPLAY`) convention.
- **MIME Type Detection**: Primary method is `file --mime-type`. Fallback to file extension heuristics (e.g., `.png` → `image/png`) if `file` is unavailable or fails.
- **Single File Only**: The script will accept exactly one file argument. If zero or more than one arguments are provided, it will error.
- **Binary and Text Files**: Both are supported. `wl-copy` will receive the raw bytes with the detected MIME type.
- **Filename Size Limit**: Default to 25MB as a safe limit for clipboard operations. Attempt one buffer copy (no chunking) because `wl-copy` handles streaming internally.
- **Metadata**: Attempt to include the original filename using the `x-special/nautilus-clipboard` format (GNOME file manager format that bundles filename with MIME type and data).
- **Error Handling**:
  - Exit non-zero on any failure.
  - Print diagnostic messages to stderr (not stdout).
- **Path Normalization**: Resolve the file path to an absolute path before copying, and echo a user-friendly version (with tilde expansion) to stdout on success.

---

## Testing Decisions

**Test Strategy**: New seams will be introduced at the `fy` script boundaries. Preferences:
- **File Boundary**: Test `fy` as a standalone command-line utility.
- **Integration Test**: Verify `fy file` followed by `fp` reproduces the file correctly (roundtrip test).
- **Isolation Test**: Verify `fy` without `fp` follows the expected success and error codes.

**Testing Conventions**:
- **Type of Testing**: Unit testing via BATS. Prior Art: The `theme-switch.bats` and `bootstrap.bats` files in `.local/scripts/tests/`
- **Test Coverage**:
  - Success cases: Regular file, image file, text file
  - Error Cases:
    - Non-existent file
    - File too large
    - Multiple files provided
    - No clipboard available
    - Unknown MIME type

---

## Out of Scope

- **Multiple Files**: `fy` will not support copying multiple files into the clipboard in one go. Users can loop over files manually if needed.
- **Non-Wayland Fallbacks**: If `wl-copy` is unavailable, `fy` will error. Other clipboard backends (xclip, xsel, OSC 52) are Out of Scope.
- **Progress Indicators**: No progress bars or verbose output for large files.
- **Directory Support**: `fy` will not copy directories (recursively or as archives).
- **Clipboard History**: `fy` will not interact with clipboard managers like `cliphist`.
- **GUI Integration**: `fy` is a CLI script only. No system tray, notifications, or GUI dialogs.

---

## Further Notes

- The filename metadata preservation (`x-special/nautilus-clipboard`) should be tested during implementation. If it proves unreliable or incompatible with sway/foot, it will be removed in favor of raw bytes + MIME type only.
- The 25MB limit is a heuristic safe for most compositors. If testing reveals issues, this can be adjusted or made configurable.
- The script should follow the repo's shell scripting style: `set -euo pipefail`, clear error messages, no subshells where avoidable, and POSIX-compliant syntax where possible.