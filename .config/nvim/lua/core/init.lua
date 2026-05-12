local o = vim.o
local opt = vim.opt
local g = vim.g

-- Tab config
o.tabstop = 4
o.softtabstop = 4
o.shiftwidth = 4
o.expandtab = true

-- Indent config
o.autoindent = true
o.smartindent = true

-- Spell check
opt.spelllang = { "de", "en" }
o.spell = true

-- Line break
o.wrap = false
o.linebreak = true
o.breakindent = true
o.showbreak = "↪ "

-- Numbers
o.number = true
o.relativenumber = true

-- Undo
o.undodir = os.getenv("HOME") .. "/.nvim/undodir"
o.undofile = true

-- Search
o.hlsearch = true
o.incsearch = false
o.smartcase = true
o.ignorecase = true

-- Term colors
o.termguicolors = true

-- Update time
o.updatetime = 250
o.timeoutlen = 300

-- Mouse
o.mouse = "a"

-- Clipboard
if os.getenv("SSH_CLIENT") or os.getenv("SSH_TTY") then
    vim.g.clipboard = {
        name = "OSC52+tunnel",
        copy = {
            ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
            ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
        },
        paste = {
            ["+"] = function()
                return vim.fn.systemlist("nc localhost 11988 2>/dev/null")
            end,
            ["*"] = function()
                return vim.fn.systemlist("nc localhost 11988 2>/dev/null")
            end,
        },
    }
end
vim.schedule(function()
    o.clipboard = "unnamedplus"
end)

-- Window border
vim.o.winborder = "rounded"

-- Sign
o.signcolumn = "yes"

-- Completion
o.completeopt = "menuone,noselect"

-- Show mode
o.showmode = false

-- Split
o.splitright = true
o.splitbelow = true

-- QOL
o.cursorline = true
o.confirm = true
g.have_nerd_font = true

-- Mapping leader key
g.mapleader = " "
g.maplocalleader = ","

require("core.lazy")
require("core.lsp")
require("core.mappings").base()
require("core.autocmds")
