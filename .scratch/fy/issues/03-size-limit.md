# 03: File Size Limit

**What to build:** (Obsolete, removed.) `fy` now copies a file _reference_
(`file://` URI), not the file's bytes, so there is nothing on the clipboard to
size-limit. This matches a file manager's Ctrl+C, which imposes no size limit.
The 25MB check and `MAX_FILE_SIZE_BYTES` variable have been removed.

**Blocked by:** 01, Core fy Script

**Status:** obsolete, removed (no bytes on the clipboard, so no size limit)

- [x] Size limit removed along with the bytes-on-clipboard approach
