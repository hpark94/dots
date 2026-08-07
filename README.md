# Dots

This repository contains my personal dotfiles. I use this configuration mainly
for working via SSH on remote servers, taking notes, and programming.

## Introduction

This setup is built for keyboard-centric workflow, optimized for efficiency and
consistency across different machines. Whether I am connected to a remote server
via SSH or working locally, I want same snappiness and set of tools.

### Key Highlights

- **Editor:** A modern **Neovim** setup specifically tailored for high-speed
  coding and structured Markdown-based note-taking.
- **Terminal & Shell:** Built for deep work. I use a custom **Tmux-sessionizer**
  script with **nested session capabilities**, allowing me to manage local and
  remote contexts simultaneously by toggling keybinding focus between nested
  sessions.
- **Design:** A custom **Light Theme** (yes, I actually prefer the light side!).
  It's designed for high legibility and reduced eye strain during long
  programming sessions in well-lit environments.
- **Philosopy:** Minimal bloat, maximum portability. The configuration is
  structured to be easily deployed on any remote machine.

## Installation

From a bare machine to a fully built one in four steps:

1. Install `git` and `stow` (stock packages on every target distro).
2. Clone this repo to `~/dots`: `git clone <repo-url> ~/dots`.
3. Export a GitHub API token: `export GITHUB_TOKEN=<token>`. A classic PAT with
   no scopes is enough. Without one, `bootstrap.sh` aborts before installing
   anything slow: the pinned toolchain pulls dozens of GitHub-hosted releases,
   and GitHub's unauthenticated ceiling of 60 requests per hour runs out partway
   through, leaving the remaining tools silently uninstalled. `mise` also
   accepts a token from an authenticated `gh` CLI, but `gh` is not part of this
   toolchain, so on a fresh machine `GITHUB_TOKEN` is the only route.
4. Run `~/dots/bootstrap.sh <desktop|headless>`.

`bootstrap.sh` handles everything else (stow, the Role Marker, `mise` and its
toolchain, tmux/nvim/zinit plugins, and the default theme state). It is
idempotent: safe to re-run, and it also retrofits a machine that already has the
dotfiles deployed by hand.
