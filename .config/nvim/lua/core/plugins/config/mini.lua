local M = {}

local indent_info_section = function(args)
    if require("mini.statusline").is_truncated(args.trunc_width) then
        return ""
    end

    local indent_type = vim.bo.expandtab and "␣ " or "↹ "
    local indent_size = vim.bo.shiftwidth > 0 and vim.bo.shiftwidth
        or vim.bo.tabstop
    return string.format("- %s:%d", indent_type, indent_size)
end

local modified_section = function()
    if vim.bo.modified then
        return "● -"
    elseif vim.bo.readonly then
        return "🔒 -"
    else
        return ""
    end
end

local my_statusline = function()
    local MiniStatusline = require("mini.statusline")
    local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
    local modified = modified_section()
    local git = MiniStatusline.section_git({ trunc_width = 40 })
    local diff = MiniStatusline.section_diff({ trunc_width = 75 })
    local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
    local lsp = MiniStatusline.section_lsp({ trunc_width = 75 })
    local filename = MiniStatusline.section_filename({ trunc_width = 140 })
    local fileinfo = MiniStatusline.section_fileinfo({ trunc_width = 120 })
    local indentinfo = indent_info_section({ trunc_width = 75 })
    local location = MiniStatusline.section_location({ trunc_width = 75 })
    local search = MiniStatusline.section_searchcount({ trunc_width = 75 })

    return MiniStatusline.combine_groups({
        { hl = mode_hl, strings = { mode } },
        {
            hl = "MiniStatuslineDevinfo",
            strings = { modified, git, diff, diagnostics, lsp },
        },
        "%<",
        { hl = "MiniStatuslineFilename", strings = { filename } },
        "%=",
        {
            hl = "MiniStatuslineFileinfo",
            strings = { fileinfo, indentinfo },
        },
        {
            hl = mode_hl,
            strings = { search, location },
        },
    })
end

M.status_line = function()
    return {
        content = {
            active = my_statusline,
            inactive = nil,
        },
        use_icons = true,
    }
end

M.ai = function()
    return {
        custom_textobjects = {
            B = MiniExtra.gen_ai_spec.buffer(),
            D = MiniExtra.gen_ai_spec.diagnostic(),
            I = MiniExtra.gen_ai_spec.indent(),
            L = MiniExtra.gen_ai_spec.line(),
        },
    }
end

M.hipatterns = function()
    return {
        highlighters = {
            hex_color = require("mini.hipatterns").gen_highlighter.hex_color(),
        },
    }
end

return M
