return {
    "nvim-mini/mini.nvim",
    version = "*",
    priority = 1000,
    config = function()
        local mini_conf = require("core.plugins.config.mini")

        require("mini.extra").setup()

        require("mini.ai").setup(mini_conf.ai())
        require("mini.bracketed").setup()
        require("mini.comment").setup()
        require("mini.hipatterns").setup(mini_conf.hipatterns())
        require("mini.icons").setup()
        require("mini.move").setup()
        require("mini.operators").setup()
        require("mini.pick").setup()
        require("mini.splitjoin").setup()
        require("mini.statusline").setup(mini_conf.status_line())
        require("mini.surround").setup()
    end,
}
