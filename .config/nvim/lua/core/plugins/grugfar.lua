return {
    "MagicDuck/grug-far.nvim",
    config = function()
        local mappings = require("core.mappings")
        require("grug-far").setup({
            -- These windows hardcode a rounded border, ignoring vim.o.winborder.
            helpWindow = { border = "single" },
            historyWindow = { border = "single" },
            previewWindow = { border = "single" },
        })
        mappings.grugfar()
    end,
}
