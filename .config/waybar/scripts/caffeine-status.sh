#!/usr/bin/env bash

if pidof systemd-inhibit >/dev/null; then
	echo '{"text": "󰅶", "class": "active", "tooltip": "Caffeine aktiv - Standby verhindert"}'
else
	echo '{"text": "󰾪", "class": "inactive", "tooltip": "Caffeine inaktiv"}'
fi
