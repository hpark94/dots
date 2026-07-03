return {
    "3rd/image.nvim",
    opts = {
        backend = "sixel",
        integrations = {
            markdown = {
                enabled = true,
                clear_in_insert_mode = false,
                download_remote_images = true,
                only_render_image_at_cursor = true,
                only_render_image_at_cursor_mode = "popup",
            },
            neorg = { enabled = true },
        },
        editor_only_render_when_focused = true,
        tmux_show_only_in_active_window = true,
        window_overlap_clear_enabled = false,
    },
}
