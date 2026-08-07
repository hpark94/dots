return {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
        lsp = {
            override = {
                ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                ["vim.lsp.util.stylize_markdown"] = true,
            },
        },
        presets = {
            bottom_search = true,
            command_palette = true,
            long_message_to_split = true,
            inc_rename = false,
            lsp_doc_border = true,
        },
        -- noice goes through nui, which ignores vim.o.winborder once a style is set.
        views = {
            hover = { border = { style = "single" } },
            popup = { border = { style = "single" } },
            cmdline_popup = { border = { style = "single" } },
            cmdline_popupmenu = { border = { style = "single" } },
            cmdline_input = { border = { style = "single" } },
            confirm = { border = { style = "single" } },
            -- This one ships borderless, so keep winborder from adding a border.
            popupmenu = { border = { style = "none" } },
        },
        routes = {
            {
                view = "notify",
                filter = { event = "msg_showmode" },
            },
        },
    },
    dependencies = {
        "MunifTanjim/nui.nvim",
    },
}
