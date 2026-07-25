# 03 — nvim cutover: JSON config, drop `--nvim-mode`, prune dropped-type keymaps, terminal wrapper

**What to build:** The editor side catches up to the rewritten `note` and its JSON config. Opening a
zettel/daily/scratch/xournal note from nvim works against the new script (no `--nvim-mode` flag);
`is_note()`/`is_in_vault()` fail closed against a missing or broken config instead of treating every
buffer on the system as a note; keymaps for deleted note types are gone; yesterday/tomorrow keymaps
pass a day offset instead of a distinct type; pasting an asset produces (and recognizes) both the old
and new link forms; and a terminal user gets a one-keystroke way to open whatever `note` just created.

**Blocked by:** [01 — `note` core: config, Role gate, and note creation](01-note-core-config-role-gate-creation.md).

**Status:** ready-for-agent

- [ ] `util.lua`'s config read is replaced: no more `bash -c "source ... && echo $VAR"` subprocess.
      `M.opts.paths.config_path` points at `~/.config/notes/config.json`, read once in `setup()` via
      `vim.json.decode` and cached, returning `nil` on a missing file, unreadable file, malformed JSON,
      or a missing/empty `vault` key.
- [ ] `is_in_vault()` gains a guard so a `nil`/empty base path returns `false` before the `vim.startswith`
      check, rather than matching every path in existence.
- [ ] `core.lua`'s `create_note` drops `--nvim-mode` from the command string it builds.
- [ ] `mappings.lua`'s `open_code`/`open_review`/`open_pinned`/`open_recipe`/`open_todo` keymaps (and
      their `<leader>nl*` link variants) are deleted, along with the corresponding functions in
      `custom/notetaking/init.lua`.
- [ ] `<leader>ndy`/`<leader>ndt` keep their keybinds but now pass a day-offset argument (`-1`/`1`)
      matching `note -d [N]`'s shape, instead of a distinct `yesterday`/`tomorrow` type.
- [ ] `custom/init.lua`'s `default_opts.commands` drops `scratch_cmd` (the `scratch` binary no longer
      exists).
- [ ] `create_asset_link` emits `![[%s]]` (no leading `../`); `delete_asset`'s line-matching pattern
      accepts both `[[../assets/...]]`/`(../assets/...)` and `[[assets/...]]`/`(assets/...)`.
- [ ] `.shell_functions.sh` gains `n() { nvim "$(note "$@")"; }`.
- [ ] Manually verified (no automated test — no Lua test framework exists in this repo): `get_base_path`
      and `is_in_vault` against a missing config, an empty config, a malformed config, and a valid
      config, confirming the first three all report "not in vault" for an arbitrary path (e.g.
      `/etc/passwd`) and the fourth correctly recognizes a path under the configured vault.
- [ ] `paste_xournal` and `open_scratch` (and their keymaps) are explicitly left untouched and
      unfixed — do not attempt to repair them here; they are out of scope per the spec and will error
      after this ticket lands (deferred to a future nvim-notetaking-integration session).

**Further Notes:** See `.scratch/notetaking-rewrite/spec.md`, Implementation Decisions → "nvim:
`custom/notetaking/util.lua`" and "nvim: `custom/notetaking/core.lua` and `mappings.lua`", and Out of
Scope for the `paste_xournal`/`open_scratch` carve-out.
