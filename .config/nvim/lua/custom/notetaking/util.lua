local M = {}

---@param opts any
M.setup = function(opts)
    M.opts = opts
end

---@return string|nil
M.get_visual = function()
    local mode = vim.fn.mode()
    if not (mode:sub(1, 1) == "v" or mode:sub(1, 1) == "V") then
        return nil
    end

    local old_reg = vim.fn.getreg('"')
    local old_regtype = vim.fn.getregtype('"')

    vim.cmd("noau normal! y")
    local text = vim.fn.getreg('"')

    vim.fn.setreg('"', old_reg, old_regtype)

    text = text:gsub("\n", " ")
    text = text:gsub("%s+", " ")
    text = vim.trim(text)

    if text == "" then
        return nil
    end

    return text
end

---@param filepath string
---@return string
M.get_basename_without_extension = function(filepath)
    local basename = vim.fn.fnamemodify(filepath, ":t:r")
    return basename
end

---@param visual_text string|nil
---@param basename string
M.create_wiki_link = function(visual_text, basename)
    return string.format("[[%s|%s]]", basename, visual_text)
end

---@param notepath string
M.get_note_path = function(notepath)
    local cmd = string.format(
        "source %s && echo $%s",
        M.opts.paths.config_path,
        notepath
    )
    return vim.trim(vim.fn.system({ "bash", "-c", cmd }))
end

---@return string
M.get_base_path = function()
    return M.get_note_path("VAULT_BASE_PATH")
end

---@return string
M.get_assets_path = function()
    return M.get_note_path("VAULT_ASSETS_PATH")
end

---@param filepath string
---@return string
M.get_relative_path = function(filepath)
    local basepath = M.get_base_path()

    basepath = vim.fn.expand(basepath)
    filepath = vim.fn.expand(filepath)

    if filepath:sub(1, #basepath + 1) == basepath .. "/" then
        return filepath:sub(#basepath + 2)
    end

    return filepath
end

---@param filepath string
---@return string
M.create_asset_link = function(filepath)
    local asset_path = M.get_relative_path(filepath)
    return string.format("![](../%s)", asset_path)
end

---@return boolean
M.is_markdown = function()
    local current_filetype = vim.bo.filetype
    local is_markdown = current_filetype == "markdown"

    if is_markdown then
        return true
    end

    return false
end

---@return boolean
M.is_in_vault = function()
    local basepath = M.get_base_path()
    local currentpath = vim.fn.expand("%:p")
    basepath = vim.fn.expand(basepath)

    if vim.startswith(currentpath, basepath) then
        return true
    end

    return false
end

---@return boolean
M.is_note = function()
    local is_markdown = M.is_markdown()
    local is_in_vault = M.is_in_vault()

    return is_markdown and is_in_vault
end

return M
