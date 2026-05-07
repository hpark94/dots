local core = require("custom.notetaking.core")
local util = require("custom.notetaking.util")
local default_opts = {
    paths = {
        config_path = vim.fn.glob("~/.config/notes/config.sh"),
    },
    commands = {
        note_cmd = vim.fn.glob("~/.local/scripts/note"),
        scratch_cmd = vim.fn.glob("~/.local/scripts/scratch"),
        filepaste_cmd = vim.fn.glob("~/.local/scripts/fp"),
    },
}

local M = {}

---@param link boolean
M.open_daily = function(link)
    core.open_note("daily", link or false)
end

---@param link boolean
M.open_yesterday = function(link)
    core.open_note("yesterday", link or false)
end

---@param link boolean
M.open_tomorrow = function(link)
    core.open_note("tomorrow", link or false)
end

---@param link boolean
M.open_zettel = function(link)
    core.open_note_with_args("zettel", link or false)
end

---@param link boolean
M.open_code = function(link)
    core.open_note_with_args("code", link or false)
end

---@param link boolean
M.open_review = function(link)
    core.open_note_with_args("review", link or false)
end

---@param link boolean
M.open_pinned = function(link)
    core.open_note_with_args("pinned", link or false)
end

---@param link boolean
M.open_recipe = function(link)
    core.open_note_with_args("recipe", link or false)
end

---@param link boolean
M.open_todo = function(link)
    core.open_note_with_args("todo", link or false)
end

M.paste_img = function()
    core.paste_img()
end

M.delete_asset = function()
    core.delete_asset()
end

M.paste_xournal = function()
    core.paste_xournal()
end

---@param new boolean
M.open_scratch = function(new)
    core.open_scratch(new)
end

---@param opts any
M.setup = function(opts)
    opts = opts or {}
    M.opts = vim.tbl_deep_extend("force", default_opts, opts)
    core.setup(M.opts)
    util.setup(M.opts)
end

return M
