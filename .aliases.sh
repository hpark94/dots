_has() { command -v "$1" >/dev/null 2>&1; }
if _has eza; then
    alias ll="eza --color=always --icons=always --sort=type -alF"
else
    alias ll="ls -laF"
fi
_has eza && alias etree="eza --color=always --icons=always --tree -a -I '.git|node_modules|.venv|__pycache__|_minted*'"
_has lazygit && alias lg="lazygit"
alias standby="systemctl suspend"
