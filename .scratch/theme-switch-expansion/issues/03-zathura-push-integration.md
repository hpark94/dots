# 03 — zathura: push integration + recolor

**What to build:** zathura's chrome (background, statusbar, inputbar, completion popup,
notifications, highlights) follows Theme Mode instead of being permanently stuck on the dark palette
it hardcodes today. Dark mode additionally recolors PDF pages themselves; light mode leaves documents
in their true colors. The existing manual recolor-toggle keybind keeps working exactly as it does
today, holding until the next theme switch reasserts the generated value.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Every color-bearing setting currently hardcoded directly in the tracked zathura config (chrome
      colors, highlight colors, and the recolor on/off + recolor light/dark colors) moves out into a
      generated fragment, included from the tracked config after its non-color settings (keybinds,
      window/scroll/font options stay tracked and unchanged). The include path is relative — zathura's
      include directive does not expand `~`.
- [ ] The generated fragment's colors resolve from the Canonical Palette per mode.
- [ ] Dark mode's fragment turns recolor on, with its light/dark recolor colors derived from the
      palette; light mode's fragment turns recolor off.
- [ ] `theme-switch` applies the change to every currently running zathura instance via its D-Bus
      config-reload method, on every switch.
- [ ] The existing manual recolor-toggle keybind is untouched and still works; a theme switch
      afterward correctly resets it back to whatever the new mode's fragment specifies (this is
      expected — zathura cannot report back a manually-overridden value for the switch to preserve).
- [ ] Manually verified: toggling dark/light with a zathura window open re-themes its chrome and
      recolor state immediately, without closing and reopening the document.
- [ ] `theme-switch.bats` gains coverage for the new generator function (exact fragment contents,
      including the recolor on/off assertion, per mode) and a guard-path smoke test for the new apply
      function ("does not error when no D-Bus method / no running instance is available").

**Further Notes:** See `.scratch/theme-switch-expansion/spec.md`, Implementation Decisions → "zathura:
push, generated fragment plus D-Bus `SourceConfig`." The config-reload method's exact re-application
of the recolor setting was confirmed by reading zathura's source, not by direct observation — confirm
it directly while implementing.
