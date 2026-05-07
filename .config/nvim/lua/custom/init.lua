require("custom.notetaking").setup({
    commands = {
        note_cmd = "note",
        scratch_cmd = "scratch",
        file_paste_cmd = "fp",
    },
})

local mappings = require("core.mappings")
mappings.notetaking()
