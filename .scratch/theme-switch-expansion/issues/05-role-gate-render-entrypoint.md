# 05: `theme-switch` Role gate + render-only entry point

**What to build:** Running `theme-switch dark`/`light`/`toggle` directly on a Headless machine
refuses with a clear error instead of silently deciding a mode it has no authority over. Separately,
a new render-only way to invoke the script exists that writes the persisted mode and runs every
generator/apply step for a given mode, without going through that refusal: this is the entry point
the Headless push (a later ticket) will call remotely, since the Desktop is the one deciding there,
not the machine rendering.

**Blocked by:** None, can start immediately.

**Status:** done

- [x] `theme-switch` reads the Role Marker using the same canonical contract already established for
      other scripts in this repo (missing, unreadable, empty, or unrecognized content are all one hard
      error naming the file and the fix; whitespace is stripped before matching).
- [x] A direct invocation (`theme-switch dark`, `theme-switch light`, `theme-switch toggle`) refuses
      with that error when the Role is `headless`, before writing or generating anything.
- [x] A new render-only invocation exists that, given an explicit mode, writes the persisted state and
      runs every existing generator and apply step for that mode, skipping the Role check entirely,
      since it's rendering a mode it was told rather than deciding one.
- [x] The render-only invocation works correctly even when no Role Marker file exists at all, proving
      it's genuinely gate-free rather than just tolerant of one particular Role value.
- [x] `theme-switch.bats` gains coverage for: the Role-read function against a
      present/absent/malformed/whitespace-padded Marker file; a direct `dark`/`light`/`toggle`
      invocation refusing on a `headless` Marker; and the render-only invocation succeeding with no
      Marker file present at all.

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation Decisions → "Role
gate added to `theme-switch` itself" and "The Headless push" (for how the render-only entry point gets
used). The Role-read contract is the canonical one pinned in [How a script reads the Role
Marker](../../portable-dotfiles/issues/13-role-marker-reader.md) (snippet in ticket 14). Match its
shape rather than inventing a new one.

## Comments

Implemented on `main`. `theme-switch` gained `read_role` (deciding-path gate: refuses with a hard
error when the Role is `headless`, and propagates `read_role`'s own hard error when the Marker is
absent/empty/unrecognized, all before any write or generate) and a `theme-switch --render <dark|light>`
entry point that skips the gate and runs `write_state` + every `generate_*` + every `apply_*`. `main`
was refactored to share a single `render()` helper across both paths, and a `usage()` was added now
that there are two invocation forms. Full `theme-switch.bats` suite passes (36/36); shellcheck clean.

**Bug found in the pinned canonical `read_role`.** The snippet pinned in
`portable-dotfiles/issues/14-script-conventions.md` reads the Marker with
`role=$(<"$marker" 2>/dev/null)`. Under bash the trailing `2>/dev/null` cancels the special
`$(<file)` fast-path, so the substitution yields the empty string for *every* file, valid or not, and
the reader rejects even a correct Marker. (It happens to work under zsh, which is why an eyeballed
copy looks fine.) Corrected here to an `[[ -r "$marker" ]]` guard plus the bare `$(<"$marker")`
fast-path (still no subprocess); path, contract, and error wording are otherwise byte-identical to the
pinned shape. **The `note` implementer must copy this corrected reader, not the pinned one**, ideally
the pinned snippet in ticket 14 gets the same fix so the two copies stay identical.

Out of this ticket's scope, confirmed still untouched: the `.tmux.conf -q` fix, the SSH push,
`.config/ssh/config.shared`, and the per-app generators (waybar/swaync/zathura/fuzzel) all belong to
other tickets. `generate_tmux` does not read the Role today, so the clipboard-rewire reconciliation
note has nothing to regress yet. The SSH push has no automated coverage by design; its manual
`ubuntu-server` verification lives with ticket 06 (the Headless push), not here.
