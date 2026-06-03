return {
    "stevearc/conform.nvim",
    opts = {
        formatters_by_ft = {
            bash = { "shfmt" },
            c = { "clang-format" },
            cpp = { "clang-format" },
            css = { "prettier" },
            html = { "prettier" },
            javascript = { "biome" },
            javascriptreact = { "biome" },
            json = { "biome" },
            jsonc = { "biome" },
            lua = { "stylua" },
            markdown = { "prettier" },
            python = { "black" },
            sh = { "shfmt" },
            tex = { "latexindent" },
            typescript = { "biome" },
            typescriptreact = { "biome" },
            yaml = { "prettier" },
        },
        formatters = {
            latexindent = {
                prepend_args = {
                    "-m",
                    "-l",
                    vim.fn.expand("~/.latexindent.yaml"),
                },
            },
        },
        format_on_save = {
            lsp_fallback = true,
            async = false,
        },
    },
}
