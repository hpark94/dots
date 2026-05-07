return {
    "MagicDuck/grug-far.nvim",
    config = function()
        local mappings = require("core.mappings")
        require("grug-far").setup({
            -- options, see Configuration section below
            -- there are no required options atm
        })
        mappings.grugfar()
    end,
}
