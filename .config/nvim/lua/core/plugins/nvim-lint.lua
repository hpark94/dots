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

        local ruleset = vim.fn.glob("~/pmd-ruleset.xml")
        local pmd = lint.linters.pmd
        pmd.args = {
            "check",
            "--format",
            "sarif",
            "--cache",
            "/tmp/pmd-cache",
            "--rulesets",
            ruleset,
            "--dir",
        }

        lint.linters_by_ft = {
            python = { "ruff" },
            c = { "clangtidy" },
            cpp = { "clangtidy" },
            bash = { "shellcheck" },
            sh = { "shellcheck" },
            java = { "pmd" },
            javascript = { "biomejs" },
            javascriptreact = { "biomejs" },
            typescript = { "biomejs" },
            typescriptreact = { "biomejs" },
        }
    end,
}
