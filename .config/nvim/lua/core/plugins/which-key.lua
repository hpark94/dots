return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        delay = 500,
        preset = "helix",
        -- The helix preset hardcodes its border, so vim.o.winborder is ignored.
        win = {
            border = "single",
        },
        icons = {
            mappings = false,
        },
    },
    keys = {
        {
            "<leader>?",
            function()
                require("which-key").show({ global = false })
            end,
            desc = "Buffer Local Keymaps (which-key)",
        },
    },
}
