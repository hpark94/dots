# 07 — Qt integration (qt6ct + Okular)

**What to build:** Wire Qt apps into `theme-switch` via a surgical edit of `qt6ct.conf`'s color-scheme key, plus session-level `QT_QPA_PLATFORMTHEME` wiring, so a freshly launched Okular picks up the right light/dark appearance after a switch.

**Blocked by:** 01 — Canonical palette + `theme-switch` skeleton

**Status:** ready-for-agent

- [ ] `patch_qt6ct(mode, target_file)` is a pure function parameterized by target file path (not hardcoded to `$HOME`), so it's testable against a scratch fixture.
- [ ] `patch_qt6ct` surgically edits only the `[Appearance]` color-scheme key in the target file, leaving every other key (style, icon theme, fonts, etc.) byte-for-byte unchanged — `qt6ct.conf` is real local app state the qt6ct GUI itself writes to, not a Generated Config fragment the script owns outright.
- [ ] Test: `patch_qt6ct` updates the color-scheme key correctly for both modes against a scratch copy of a fixture `qt6ct.conf` containing unrelated pre-existing keys, and those keys are unchanged afterward.
- [ ] `main()` calls `patch_qt6ct` against `$XDG_CONFIG_HOME/qt6ct/qt6ct.conf`; it's a no-op if the file doesn't exist yet (qt6ct not installed/configured).
- [ ] No live-apply exists for Qt (same Next-launch category as ghostty) — already-open Okular windows don't update; new ones do.
- [ ] `QT_QPA_PLATFORMTHEME=qt6ct` is set once via sway's session-start environment (alongside the existing `dbus-update-activation-environment` line), not a shell rc file, so GUI-launched Qt apps pick it up too.
- [ ] `CONTEXT.md`'s **Next-launch app** definition is updated to include Qt alongside ghostty/nvim/bat/fzf.
- [ ] `qt6ct.conf` itself is not git-tracked or stowed — confirm nothing in this ticket adds it to the repo.
- [ ] Verified manually, to the extent possible in sandbox: `patch_qt6ct` against a real `qt6ct.conf` fixture produces the expected key value for both modes. Real end-to-end verification (installing `qt6ct` + Okular, running the qt6ct GUI once for base preferences, then confirming a freshly launched Okular reflects `theme-switch dark`/`light`) requires a real desktop session and is noted as a pending manual spot-check, per the precedent set in ticket 04.
