return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter").setup({
            install_dir = vim.fn.stdpath("data") .. "/site",
        })
        require("nvim-treesitter").install({
            "bash",
            "c",
            "cpp",
            "css",
            "dtd",
            "html",
            "java",
            "javascript",
            "json",
            "lua",
            "markdown",
            "markdown_inline",
            "properties",
            "python",
            "query",
            "regex",
            "scss",
            "sql",
            "svelte",
            "tsx",
            "typescript",
            "typst",
            "vim",
            "vimdoc",
            "vue",
            "xml",
            "yaml",
        })
    end,
}
