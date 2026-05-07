local map = function(mode, keys, func, desc)
    vim.keymap.set(mode, keys, func, { desc = desc })
end

M = {}

M.base = function()
    map("n", "<Esc>", function()
        vim.cmd("noh")
    end, "Remove Highlight")
    map("n", "<C-f>", function()
        vim.cmd("silent !tmux neww tmux-sessionizer")
    end, "TMUX-Sessionizer")

    map("i", "jj", "<ESC>", "Escape")
    map("n", "<leader>vs", function()
        vim.cmd.vsplit()
    end, "Make vertical split")
    map("n", "<leader>hs", function()
        vim.cmd.split()
    end, "Make horizontal split")
    map({ "n", "v" }, "<leader>tf", function()
        require("custom.notetaking.core").delete_asset()
    end, "Test function")
end

M.grugfar = function()
    local grugfar = require("grug-far")

    map("n", "<leader>rr", function()
        grugfar.open()
    end, "Search/Replace")
    map("n", "<leader>rc", function()
        grugfar.open({
            prefills = { paths = vim.fn.expand("%") },
        })
    end, "Search/Replace current file")
end

M.notetaking = function()
    local note = require("custom.notetaking")

    map("n", "<leader>ndd", function()
        note.open_daily(false)
    end, "Open daily note")
    map("n", "<leader>ndy", function()
        note.open_yesterday(false)
    end, "Open yesterday note")
    map("n", "<leader>ndt", function()
        note.open_tomorrow(false)
    end, "Open tomorrow note")

    map("n", "<leader>noz", function()
        note.open_zettel(false)
    end, "Open new zettel note")
    map("n", "<leader>norc", function()
        note.open_recipe(false)
    end, "Open new recipe note")
    map("n", "<leader>norv", function()
        note.open_review(false)
    end, "Open new review note")
    map("n", "<leader>noc", function()
        note.open_code(false)
    end, "Open new code note")
    map("n", "<leader>not", function()
        note.open_todo(false)
    end, "Open new todo note")
    map("n", "<leader>nop", function()
        note.open_pinned(false)
    end, "Open new pinned note")

    map({ "n", "v" }, "<leader>nlz", function()
        note.open_zettel(true)
    end, "Link new zettel note")
    map({ "n", "v" }, "<leader>nlrc", function()
        note.open_recipe(true)
    end, "Link new recipe note")
    map({ "n", "v" }, "<leader>nlrv", function()
        note.open_review(true)
    end, "Link new review note")
    map({ "n", "v" }, "<leader>nlc", function()
        note.open_code(true)
    end, "Link new code note")
    map({ "n", "v" }, "<leader>nlt", function()
        note.open_todo(true)
    end, "Link new todo note")
    map({ "n", "v" }, "<leader>nlp", function()
        note.open_pinned(true)
    end, "Link new pinned note")

    map("n", "<leader>nfp", function()
        note.paste_img()
    end, "Paste and link file")
    map("i", "<C-f>", function()
        note.paste_img()
    end, "Paste and link file")
    map("n", "<leader>nx", function()
        note.paste_xournal()
    end, "Create new Xournal and link")
    map("n", "<leader>nfd", function()
        note.delete_asset()
    end, "Delete asset")

    map("n", "<leader>nsn", function()
        note.open_scratch(true)
    end, "Open new scratch")
    map("n", "<leader>nsl", function()
        note.open_scratch(false)
    end, "Open last scratch")
end

M.oil = function()
    map("n", "<leader>o", function()
        vim.cmd("Oil")
    end, "Open Oil")
end

M.notify = function()
    map("n", "<leader>hs", function()
        local notifications = require("notify").history()

        local buf = vim.api.nvim_create_buf(false, true)

        vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
        vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
        vim.api.nvim_buf_set_name(buf, "Notifications")

        local lines = {}

        for _, n in ipairs(notifications) do
            local time_str = vim.fn.strftime("%H:%M:%S", n.time)

            table.insert(
                lines,
                string.format("[%s] %s %s", time_str, n.level, n.icon)
            )

            if n.title and n.title[1] and n.title[1] ~= "" then
                table.insert(lines, "Title: " .. n.title[1])
            end

            for _, msg in ipairs(n.message) do
                table.insert(lines, msg)
            end

            table.insert(lines, "")
        end

        if #lines == 0 then
            table.insert(lines, "No notifications found")
        end

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

        local width = math.floor(vim.o.columns * 0.8)
        local height = math.floor(vim.o.lines * 0.8)
        local opts = {
            relative = "editor",
            width = width,
            height = height,
            col = math.floor((vim.o.columns - width) / 2),
            row = math.floor((vim.o.lines - height) / 2),
            style = "minimal",
            border = "rounded",
            title = " Notifications ",
            title_pos = "center",
        }

        local win = vim.api.nvim_open_win(buf, true, opts)

        vim.api.nvim_set_option_value(
            "winhighlight",
            "Normal:NotificationFloat",
            { win = win }
        )

        vim.api.nvim_buf_set_keymap(
            buf,
            "n",
            "q",
            "<cmd>close<cr>",
            { noremap = true, silent = true }
        )
    end, "Show Notifications History")
end

M.jdtls = function()
    map("n", "<leader>lt", function()
        require("jdtls.tests").generate()
    end, "Generate Java Test")
    map("n", "<leader>lj", function()
        require("jdtls.tests").goto_subjects()
    end, "Jump to Java tests or subjects")
end

return M
