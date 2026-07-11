vim.opt.background = "dark"
vim.g.colors_name = "hp_dark"

package.loaded["lush_theme.hp_dark"] = nil

require("lush")(require("lush_theme.hp_dark"))
