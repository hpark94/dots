return {
    "mfussenegger/nvim-jdtls",
    config = function()
        local mappings = require("core.mappings")
        mappings.jdtls()
    end,
}
