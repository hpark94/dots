# Roster

The programs a Desktop machine needs, and the package that supplies each on
Fedora and on Ubuntu. The set is Desktop: it says nothing about what a Headless
machine should have. The first column is a command name, not a package name: it
is the command the machine must have. A `-` in a package column means this
install line does not install it, while a `-` in the first column means the row
leaves no command on `PATH`. Package names may repeat down a column, because one
package can carry several commands.

| binary                               | fedora                   | ubuntu                     |
| ------------------------------------ | ------------------------ | -------------------------- |
| -                                    | `fcitx5-gtk`             | `fcitx5-frontend-gtk3`     |
| -                                    | `fcitx5-gtk`             | `fcitx5-frontend-gtk4`     |
| -                                    | `fcitx5-hangul`          | `fcitx5-hangul`            |
| -                                    | `fcitx5-qt`              | `fcitx5-frontend-qt5`      |
| -                                    | `fcitx5-qt`              | `fcitx5-frontend-qt6`      |
| -                                    | `glibc-devel`            | `build-essential`          |
| -                                    | `python3-i3ipc`          | `python3-i3ipc`            |
| -                                    | `sway-systemd`           | -                          |
| -                                    | `xdg-desktop-portal-gtk` | `xdg-desktop-portal-gtk`   |
| -                                    | `xdg-desktop-portal-wlr` | `xdg-desktop-portal-wlr`   |
| -                                    | `zathura-pdf-poppler`    | `zathura-pdf-poppler`      |
| `blueman-manager`                    | `blueman`                | `blueman`                  |
| `brightnessctl`                      | `brightnessctl`          | `brightnessctl`            |
| `chafa`                              | `chafa`                  | `chafa`                    |
| `cliphist`                           | `cliphist`               | `cliphist`                 |
| `curl`                               | `curl`                   | `curl`                     |
| `dbus-update-activation-environment` | `dbus-tools`             | `dbus-bin`                 |
| `dig`                                | `bind-utils`             | `bind9-dnsutils`           |
| `fc-cache`                           | `fontconfig`             | `fontconfig`               |
| `fcitx5`                             | `fcitx5`                 | `fcitx5`                   |
| `fcitx5-config-qt`                   | `fcitx5-configtool`      | `fcitx5-config-qt`         |
| `ffmpeg`                             | -                        | `ffmpeg`                   |
| `file`                               | `file`                   | `file`                     |
| `flatpak`                            | `flatpak`                | `flatpak`                  |
| `foot`                               | `foot`                   | `foot`                     |
| `fuzzel`                             | `fuzzel`                 | `fuzzel`                   |
| `g++`                                | `gcc-c++`                | `build-essential`          |
| `gcc`                                | `gcc`                    | `build-essential`          |
| `gdbus`                              | `glib2`                  | `libglib2.0-bin`           |
| `ghostty`                            | `ghostty`                | `ghostty`                  |
| `git`                                | `git`                    | `git`                      |
| `grim`                               | `grim`                   | `grim`                     |
| `gsettings`                          | `glib2`                  | `libglib2.0-bin`           |
| `htop`                               | `htop`                   | `htop`                     |
| `imv-wayland`                        | `imv`                    | `imv`                      |
| `jq`                                 | `jq`                     | `jq`                       |
| `keepassxc`                          | `keepassxc`              | `keepassxc`                |
| `kitten`                             | `kitty-kitten`           | `kitty`                    |
| `latexindent`                        | `texlive-latexindent`    | `texlive-extra-utils`      |
| `latexmk`                            | `latexmk`                | `latexmk`                  |
| `librewolf`                          | `librewolf`              | `librewolf`                |
| `lxpolkit`                           | `lxpolkit`               | `lxpolkit`                 |
| `make`                               | `make`                   | `build-essential`          |
| `metaflac`                           | `flac`                   | `flac`                     |
| `mpv`                                | `mpv`                    | `mpv`                      |
| `nm-connection-editor`               | `nm-connection-editor`   | `nm-connection-editor`     |
| `nmcli`                              | `NetworkManager`         | `network-manager`          |
| `notify-send`                        | `libnotify`              | `libnotify-bin`            |
| `pavucontrol`                        | `pavucontrol`            | `pavucontrol`              |
| `pgrep`                              | `procps-ng`              | `procps`                   |
| `playerctl`                          | `playerctl`              | `playerctl`                |
| `python3`                            | `python3`                | `python3`                  |
| `satty`                              | `satty`                  | -                          |
| `ssh`                                | `openssh-clients`        | `openssh-client`           |
| `stow`                               | `stow`                   | `stow`                     |
| `sway`                               | `sway`                   | `sway`                     |
| `swaybg`                             | `swaybg`                 | `swaybg`                   |
| `swayidle`                           | `swayidle`               | `swayidle`                 |
| `swaylock`                           | `swaylock`               | `swaylock`                 |
| `swaymsg`                            | `sway`                   | `sway`                     |
| `swaync`                             | `SwayNotificationCenter` | `sway-notification-center` |
| `swaync-client`                      | `SwayNotificationCenter` | `sway-notification-center` |
| `systemd-inhibit`                    | `systemd`                | `systemd`                  |
| `thunar`                             | `Thunar`                 | `thunar`                   |
| `tput`                               | `ncurses`                | `ncurses-bin`              |
| `unzip`                              | `unzip`                  | `unzip`                    |
| `upower`                             | `upower`                 | `upower`                   |
| `waybar`                             | `waybar`                 | `waybar`                   |
| `wl-copy`                            | `wl-clipboard`           | `wl-clipboard`             |
| `wl-paste`                           | `wl-clipboard`           | `wl-clipboard`             |
| `wpctl`                              | `wireplumber`            | `wireplumber`              |
| `xdg-open`                           | `xdg-utils`              | `xdg-utils`                |
| `zathura`                            | `zathura`                | `zathura`                  |
| `zsh`                                | `zsh`                    | `zsh`                      |
