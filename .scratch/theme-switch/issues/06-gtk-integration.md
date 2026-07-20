# 06 — GTK integration

**What to build:** Wire GTK apps into `theme-switch` so a freshly launched evince, xarchiver, pavucontrol, or Librewolf reflects the current Theme Mode, regardless of how it was launched (terminal, app launcher, file manager).

**Blocked by:** 01 — Canonical palette + `theme-switch` skeleton

**Status:** ready-for-agent

- [x] `apply_gtk(mode)` runs `gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark|Adwaita-light`.
- [x] `apply_gtk` also runs `gsettings set org.gnome.desktop.interface color-scheme prefer-dark|prefer-light`, needed for portal-aware apps (Librewolf) that don't consume `gtk-theme` — see Comments.
- [x] `apply_gtk` is guarded by `command -v gsettings`, matching the existing `command -v tmux`/`swaymsg` guard pattern used by `apply_tmux`/`apply_sway`.
- [x] No Generated Config fragment is written for GTK — dconf already persists the gsettings value durably.
- [x] `main()` calls `apply_gtk` alongside the other apply steps.
- [x] `CONTEXT.md`'s **Next-launch app** definition is updated to include GTK, covering both the classic-app (`gtk-theme`) and portal-aware-app (`color-scheme`) consumer categories.
- [x] Verified manually: `theme-switch dark` then `theme-switch light`, each followed by a fresh launch of evince, pavucontrol, and Librewolf, screenshotted to confirm the actual rendered appearance matches the mode.

## Comments

The originally designed mechanism (`gsettings set org.gnome.desktop.interface color-scheme prefer-dark|prefer-light`, plus the legacy `gtk-application-prefer-dark-theme` boolean, both applied live) turned out to have **zero visible effect** on any of the three installed apps, caught by actually running the script and screenshotting fresh app launches rather than trusting the design:

- `color-scheme` is only consumed by libadwaita's `AdwStyleManager`. Checked via `ldd`: neither evince (plain GTK4) nor xarchiver/pavucontrol (plain GTK3) link libadwaita, so nothing in their process reads that key at all.
- The legacy `gtk-application-prefer-dark-theme` boolean doesn't exist in this system's `gsettings-desktop-schemas` (v50.1) — `gsettings list-keys` confirms it's gone. Even where it does exist elsewhere, gnome-settings-daemon is normally what bridges `color-scheme` into that boolean for old apps to see, and sway doesn't run gnome-settings-daemon.
- Verified this had no effect via a clean test: set `color-scheme` to `prefer-dark`, confirmed via the freedesktop Settings portal (`busctl call ... org.freedesktop.portal.Settings Read`) that the value really did propagate to `1` (dark), then freshly launched both evince and pavucontrol and screenshotted them — both rendered light.

An `Adwaita:dark`-style `GTK_THEME` env var was tried next (GTK's own built-in theme-name override) and *did* visibly force both apps dark when set directly on the command line — but making that reach GUI-launcher-invoked apps (not just terminal-launched ones) would need `systemctl --user set-environment`/`dbus-update-activation-environment`. Tracing through how this system actually launches apps (sway's `exec`, fuzzel as the app launcher) showed that mechanism wouldn't help: both sway and fuzzel fork children from their own already-resident process environment, not a freshly-queried systemd/dbus table, so an already-running launcher would never see the update. This was rejected as unreliable rather than shipped on faith.

The mechanism that actually works, found by testing one level deeper: `gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"` (the theme *name* key, not `color-scheme`) is read directly by `GtkSettings` in every GTK2/3/4 app at that app's own startup — a persistent, daemon-backed (dconf) setting, so there's no launcher-inheritance problem at all, unlike the env-var approach. Confirmed via fresh-launch screenshots for both evince and pavucontrol in both modes, using the real `theme-switch dark`/`light` commands (not manual gsettings calls). Also confirmed via screenshot that an already-running instance does *not* re-theme when the value changes — so GTK ended up in the **Next-launch** category, not Live-switchable as originally designed; `CONTEXT.md` was corrected accordingly.

**Follow-up, after shipping:** Librewolf (also GTK3) still didn't react to the `gtk-theme` fix. Rather than more screenshot-driven trial and error, checked `strings` on Librewolf's `libxul.so` directly: it has `org.freedesktop.appearance` and `org.freedesktop.portal.Settings` compiled in, meaning it reads the XDG desktop portal's appearance setting — fed by `color-scheme`, not `gtk-theme` — exactly the key the original design used and this ticket dropped. So `color-scheme` wasn't actually wrong to want, it was just insufficient on its own for the three original apps; it's *also* necessary, for a different category of app. `apply_gtk` now sets both keys together. Confirmed via a fresh Librewolf window screenshot after a real `theme-switch dark` that it picks up `color-scheme` correctly — interestingly, this landed as a *new window in the already-running process*, not a fresh process, since Librewolf's own portal subscription is live inside its process even though `theme-switch` itself provides no live-apply signal for GTK.
