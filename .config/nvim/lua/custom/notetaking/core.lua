local util = require("custom.notetaking.util")

local M = {}

---@param opts any
M.setup = function(opts)
    M.opts = opts
end

---@param note_mode string
---@param title string|nil
M.create_note = function(note_mode, title)
    local cmd
    if title and title ~= "" then
        cmd = string.format(
            "%s --nvim-mode --%s %q",
            M.opts.commands.note_cmd,
            note_mode,
            title
        )
    else
        cmd = string.format(
            "%s --nvim-mode --%s",
            M.opts.commands.note_cmd,
            note_mode
        )
    end

    local handle = io.popen(cmd)
    if not handle then
        vim.notify(
            string.format("Error: Could not open %s note", note_mode),
            vim.log.levels.WARN
        )
        return
    end

    local filepath = handle:read("*a"):gsub("%s+", "")
    handle:close()

    if filepath == "" then
        return nil
    end

    return filepath
end

---@param note_mode string
---@param link boolean
---@param title string|nil
M.open_note = function(note_mode, link, title)
    local filepath = M.create_note(note_mode, title)
    if not filepath then
        vim.notify("No file was created - aborting", vim.log.levels.WARN)
        return
    end

    local is_note = util.is_note()
    if is_note and link then
        local basename = util.get_basename_without_extension(filepath)
        local wiki_link = util.create_wiki_link(title, basename)

        vim.cmd("normal! gv")
        vim.cmd("normal! c" .. wiki_link)
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
end

---@param note_mode string
---@param link boolean
M.open_note_with_args = function(note_mode, link)
    local title = util.get_visual()

    if not title then
        title = vim.fn.input("Title: ")
        title = vim.trim(title)
        if title == "" then
            vim.notify("No title provided – aborting", vim.log.levels.WARN)
            return
        end
    end

    M.open_note(note_mode, link, title)
end

M.paste_img = function()
    local is_note = util.is_note()
    if not is_note then
        vim.notify("Not a note - aborting", vim.log.levels.WARN)
        return
    end

    local assets_path = util.get_assets_path()

    local cmd =
        string.format("%s %s", M.opts.commands.filepaste_cmd, assets_path)
    local handle = io.popen(cmd .. " 2>/dev/null")

    if not handle then
        vim.notify(
            "Error: Could not execute file paste cmd",
            vim.log.levels.WARN
        )
        return
    end

    local filepath = handle:read("*a"):gsub("%s+", "")
    local success = handle:close()

    if not success or filepath == "" then
        vim.notify("No image or file in clipboard", vim.log.levels.INFO)
        return
    end

    local asset_link = util.create_asset_link(filepath)
    vim.api.nvim_put({ asset_link }, "c", false, true)
    vim.notify("Asset pasted", vim.log.levels.INFO)
end

M.delete_asset = function()
    local is_note = util.is_note()
    if not is_note then
        vim.notify("Not a note - aborting", vim.log.levels.WARN)
        return
    end

    local assets_path = util.get_assets_path()
    local line = vim.api.nvim_get_current_line()

    local filename = line:match("%[%[assets/([^%]]+)%]%]")
        or line:match("%(assets/([^%)]+)%)")

    if not filename then
        vim.notify("No asset found in current line", vim.log.levels.WARN)
        return
    end

    local confirm = vim.fn.input("Delete " .. filename .. "= (y/n): ")
    if confirm:lower() ~= "y" then
        vim.notify("Deletion cancelled", vim.log.levels.INFO)
        return
    end

    local full_path = assets_path .. "/" .. filename
    local success = os.remove(full_path)

    if success then
        vim.cmd("normal! dd")
        vim.notify("Asset deleted: " .. filename, vim.log.levels.INFO)
    else
        vim.notify("Failed to delete: " .. full_path, vim.log.levels.ERROR)
    end
end

M.paste_xournal = function()
    local is_note = util.is_note()
    if not is_note then
        vim.notify("Not a note - aborting", vim.log.levels.WARN)
        return
    end

    local assets_path = util.get_assets_path()

    local cmd =
        string.format("%s --nvim-mode --xournal", M.opts.commands.note_cmd)

    local handle = io.popen(cmd)
    if not handle then
        vim.notify(
            "Error: Could not execute file paste cmd",
            vim.log.levels.WARN
        )
        return
    end

    local filepath = handle:read("*a"):gsub("%s+", "")
    handle:close()

    if filepath == "" then
        vim.notify(
            "Error: Could not paste img to directory",
            vim.log.levels.WARN
        )
        return
    end

    local asset_link = util.create_asset_link(filepath)
    vim.api.nvim_put({ asset_link }, "c", false, true)
end

---@param new boolean
M.open_scratch = function(new)
    local flag
    if new then
        flag = "--new"
    else
        flag = "--last"
    end

    local cmd =
        string.format("%s %s --nvim-mode", M.opts.commands.scratch_cmd, flag)

    local handle = io.popen(cmd)
    if not handle then
        vim.notify("Error: Could not open scratch", vim.log.levels.WARN)
        return
    end

    local filepath = handle:read("*a"):gsub("%s+", "")
    handle:close()

    if filepath == "" then
        vim.notify("No file was created - aborting", vim.log.levels.WARN)
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
end

return M
