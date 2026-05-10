return {
    "saghen/blink.cmp",
    dependencies = {
        "L3MON4D3/LuaSnip",
        "folke/lazydev.nvim",
        "nvim-tree/nvim-web-devicons",
        "onsails/lspkind.nvim",
    },
    event = "VimEnter",
    version = "1.*",
    opts = {
        signature = { enabled = true },
        appearance = {
            use_nvim_cmp_as_default = false,
            nerd_font_variant = "mono",
        },
        sources = {
            default = { "lazydev", "lsp", "path", "snippets", "buffer" },
            providers = {
                cmdline = {
                    min_keyword_length = 2,
                },
                lazydev = {
                    name = "LazyDev",
                    module = "lazydev.integrations.blink",
                    score_offset = 100,
                },
            },
        },
        keymap = {
            ["<C-space>"] = { "select_and_accept", "fallback" },
        },
        cmdline = {
            enabled = false,
        },
        completion = {
            menu = {
                border = "rounded",
                scrolloff = 2,
                scrollbar = false,
                draw = {
                    columns = {
                        { "kind_icon", "kind", gap = 1 },
                        { "label", "label_description", gap = 1 },
                        { "source_name" },
                    },
                },
            },
            documentation = {
                window = {
                    border = "rounded",
                    max_width = 50,
                    scrollbar = false,
                    winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc",
                },
                auto_show = true,
                auto_show_delay_ms = 500,
            },
        },
    },
}
