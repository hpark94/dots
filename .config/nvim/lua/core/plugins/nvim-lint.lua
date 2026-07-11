return {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        local lint = require("lint")

        local shellcheck = lint.linters.shellcheck
        shellcheck.args = {
            "-x",
            "--format=gcc",
        }

        lint.linters_by_ft = {
            python = { "ruff" },
            c = { "clangtidy" },
            cpp = { "clangtidy" },
            bash = { "shellcheck" },
            sh = { "shellcheck" },
            javascript = { "biomejs" },
            javascriptreact = { "biomejs" },
            typescript = { "biomejs" },
            typescriptreact = { "biomejs" },
        }
    end,
}
