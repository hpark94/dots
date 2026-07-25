# 05 — `theme-switch` Role gate + render-only entry point

**What to build:** Running `theme-switch dark`/`light`/`toggle` directly on a Headless machine
refuses with a clear error instead of silently deciding a mode it has no authority over. Separately,
a new render-only way to invoke the script exists that writes the persisted mode and runs every
generator/apply step for a given mode, without going through that refusal — this is the entry point
the Headless push (a later ticket) will call remotely, since the Desktop is the one deciding there,
not the machine rendering.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `theme-switch` reads the Role Marker using the same canonical contract already established for
      other scripts in this repo (missing, unreadable, empty, or unrecognized content are all one hard
      error naming the file and the fix; whitespace is stripped before matching).
- [ ] A direct invocation (`theme-switch dark`, `theme-switch light`, `theme-switch toggle`) refuses
      with that error when the Role is `headless`, before writing or generating anything.
- [ ] A new render-only invocation exists that, given an explicit mode, writes the persisted state and
      runs every existing generator and apply step for that mode — skipping the Role check entirely,
      since it's rendering a mode it was told rather than deciding one.
- [ ] The render-only invocation works correctly even when no Role Marker file exists at all, proving
      it's genuinely gate-free rather than just tolerant of one particular Role value.
- [ ] `theme-switch.bats` gains coverage for: the Role-read function against a
      present/absent/malformed/whitespace-padded Marker file; a direct `dark`/`light`/`toggle`
      invocation refusing on a `headless` Marker; and the render-only invocation succeeding with no
      Marker file present at all.

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation Decisions → "Role
gate added to `theme-switch` itself" and "The Headless push" (for how the render-only entry point gets
used). The Role-read contract is the same one already established for `note` in the notetaking-rewrite
spec — match its shape rather than inventing a new one.
