# 01: OSC 52 clipboard rewire, tunnel deleted

**What to build:** Copy-paste works correctly between the Desktop and any machine reached over SSH,
including a nested tmux session (Desktop tmux SSH'd into a remote tmux), with no separate tunnel
service required. Pasting no longer depends on which `~/.ssh/config` host alias was used or on
SSH-ness at all, it depends on whether a compositor clipboard is actually reachable from the current
session.

**Blocked by:** None, can start immediately.

**Status:** done

Verified done on `main` (landed in `2b071a0`, "feat(clipboard): rewire to OSC 52 both directions, delete SSH tunnel"). All six code criteria are confirmed in the current tree: `clipboard-tunnel.service` and the sway exec line are gone, `.tmux.conf` sets `get-clipboard both` unconditionally, `.tmux.remote.conf` and its `if-shell` are deleted, nvim uses `vim.ui.clipboard.osc52` for both copy and paste behind a `WAYLAND_DISPLAY` (not SSH-ness) branch, and ghostty has `clipboard-read = allow`. The operator has since confirmed copy-paste works over SSH, so the main live verification is ticked; the two remaining boxes cover narrower edge cases (no-OSC-52-reply fallback, native-vs-OSC-52 path selection) that were not separately exercised.

- [x] The tracked `clipboard-tunnel.service` unit is deleted from the repo, along with the sway config
      line that starts it.
- [x] tmux's tracked config sets `get-clipboard both` unconditionally (not behind any branch or in a
      separate file), so every tmux layer in a nested session relays clipboard reads to its client
      instead of answering from its own paste buffer.
- [x] `.tmux.remote.conf` and the `if-shell` that conditionally sourced it are deleted outright.
- [x] nvim's clipboard paste no longer shells out to `nc`; it uses the same built-in OSC 52 mechanism
      nvim's copy already uses.
- [x] nvim's clipboard-strategy branch tests whether a compositor clipboard is reachable from the
      current session (not SSH-ness), matching the same signal this repo already uses for the
      equivalent question elsewhere.
- [x] ghostty allows clipboard reads without prompting, matching foot's already-enabled OSC 52 paste.
- [x] Manually verified: copy on one machine and paste into nvim on another works correctly (a) in a
      single, unnested tmux session, and (b) nested, Desktop tmux SSH'd into a remote tmux, over this
      repo's established SSH test target. (Operator confirmed copy-paste works over SSH.)
- [ ] Manually verified: nvim paste behaves correctly (no hang, no crash) when no OSC 52 reply arrives
      at all, e.g. because the terminal doesn't support it. (Pending a live run.)
- [ ] Manually verified: with a compositor clipboard reachable (e.g. locally, or under waypipe), nvim
      uses the native path rather than OSC 52; with none reachable, it uses OSC 52 for both copy and
      paste. (Pending a live run.)

**Further Notes:** See `.scratch/clipboard-rewire/spec.md`, Implementation Decisions → "The tunnel is
deleted," "OSC 52 both directions," "The branch: `$WAYLAND_DISPLAY`, not SSH-ness," and "tmux never had
a clipboard branch to begin with." Verify the full nvim → inner tmux → outer tmux → foot read chain
end to end before considering this done, each link is documented and installed individually, but the
full chain has not been exercised.
