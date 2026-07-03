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
        max_width_window_percentage = 50,
        max_height_window_percentage = 30,
        window_overlap_clear_enabled = false,
    },
}
