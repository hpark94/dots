#!/usr/bin/env bash
swaymsg workspace $(($(swaymsg -t get_workspaces | jq '.[] | select(.focused).num') + 1))
