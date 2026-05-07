return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
        bigfile = { enabled = true },
        bufdelete = { enabled = true },
        image = {
            enabled = true,
            math = { enabled = false },
            convert = {
                notify = false,
            },
        },
        picker = { enabled = true },
        notifier = { enabled = true },
        quickfile = { enabled = true },
        statuscolumn = { enabled = true },
    },
    keys = {
        {
            "<leader>hh",
            function()
                Snacks.notifier.show_history()
            end,
            desc = "Search files",
        },
        {
            "<leader>sf",
            function()
                Snacks.picker.files()
            end,
            desc = "Search files",
        },
        {
            "<leader>sc",
            function()
                Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
            end,
            desc = "Search config files",
        },
        {
            "<leader>sd",
            function()
                Snacks.picker.diagnostics()
            end,
            desc = "Search diagnostics",
        },
        {
            "<leader>sh",
            function()
                Snacks.picker.help()
            end,
            desc = "Search help",
        },
        {
            "<leader>sg",
            function()
                Snacks.picker.grep()
            end,
            desc = "Search by grep",
        },
        {
            "<leader>/",
            function()
                Snacks.picker.grep_buffers()
            end,
            desc = "Grep Buffers",
        },
        {
            "<leader>su",
            function()
                Snacks.picker.undo()
            end,
            desc = "Undo History",
        },
        {
            "<leader>sj",
            function()
                Snacks.picker.jumps()
            end,
            desc = "Jumps",
        },
        {
            "<leader>sm",
            function()
                Snacks.picker.marks()
            end,
            desc = "Marks",
        },
        {
            "<C-x>",
            function()
                Snacks.bufdelete()
            end,
            desc = "Delete Buffer",
        },
        {
            "<leader><leader>",
            function()
                Snacks.picker.buffers()
            end,
            desc = "Opened Buffers",
        },
    },
}
