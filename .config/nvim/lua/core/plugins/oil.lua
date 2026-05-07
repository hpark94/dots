return {
    "stevearc/oil.nvim",
    config = function()
        require("oil").setup({
            view_options = {
                show_hidden = true,
            },
            keymaps = {
                ["q"] = "actions.close",
            },
        })
        require("core.mappings").oil()
    end,
}
