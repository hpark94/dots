return {
    "rktjmp/lush.nvim",
    {
        dir = vim.fn.expand("~/.config/nvim/lush_theme/"),
        config = function()
            vim.cmd.colorscheme("royalfox")
        end,
    },
}
