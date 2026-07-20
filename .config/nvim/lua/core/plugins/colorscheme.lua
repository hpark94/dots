local function theme_mode()
    local state_home = os.getenv("XDG_STATE_HOME")
    if state_home == nil or state_home == "" then
        state_home = os.getenv("HOME") .. "/.local/state"
    end
    local file = io.open(state_home .. "/theme/mode", "r")
    if not file then
        return "light"
    end
    local mode = file:read("*l")
    file:close()
    if mode == "dark" or mode == "light" then
        return mode
    end
    return "light"
end

return {
    "rktjmp/lush.nvim",
    {
        dir = vim.fn.expand("~/.config/nvim/lush_theme/"),
        config = function()
            vim.cmd.colorscheme("hp_" .. theme_mode())
        end,
    },
}
