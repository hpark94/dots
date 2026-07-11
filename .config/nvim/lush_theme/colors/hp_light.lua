vim.opt.background = "light"
vim.g.colors_name = "hp_light"

package.loaded["lush_theme.hp_light"] = nil

require("lush")(require("lush_theme.hp_light"))
