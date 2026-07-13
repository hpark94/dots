local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local ok, Snacks = pcall(require, "snacks")
local use_snacks = ok and Snacks.picker ~= nil

-- Reload buffer
autocmd({ "FocusGained", "BufEnter" }, {
    group = augroup("reload_buffer", { clear = true }),
    callback = function()
        if vim.fn.getcmdwintype() ~= "" then
            return
        end
        vim.cmd("checktime")
    end,
})

-- Highlight yank
autocmd("TextYankPost", {
    group = augroup("highlight_yank", { clear = true }),
    pattern = "*",
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = 100,
        })
    end,
})

-- LSP
autocmd("LspAttach", {
    group = augroup("lsp-attach", { clear = true }),
    callback = function(event)
        local map = function(keys, func, desc)
            vim.keymap.set(
                "n",
                keys,
                func,
                { buffer = event.buf, desc = "LSP: " .. desc }
            )
        end

        if use_snacks then
            map("gd", function()
                Snacks.picker.lsp_definitions()
            end, "Goto Definition")
            map("K", function()
                vim.lsp.buf.hover({ border = "rounded" })
            end, "LSP Hover")
            map("gD", function()
                Snacks.picker.lsp_declarations()
            end, "Goto Declaration")
            map("gR", function()
                Snacks.picker.lsp_references()
            end, "References")
            map("gi", function()
                Snacks.picker.lsp_implementations()
            end, "Goto Implementation")
            map("gy", function()
                Snacks.picker.lsp_type_definitions()
            end, "Goto T[y]pe Definition")
            map("<leader>ls", function()
                Snacks.picker.lsp_symbols()
            end, "LSP Symbols")
            map("<leader>lS", function()
                Snacks.picker.lsp_workspace_symbols()
            end, "LSP Workspace Symbols")
        else
            --stylua: ignore start
            map("gd", vim.lsp.buf.definition, "Goto Definition")
            map("gD", vim.lsp.buf.declaration, "Goto Declaration")
            map("gR", vim.lsp.buf.references, "References")
            map("gi", vim.lsp.buf.implementation, "Goto Implementation")
            map("gy", vim.lsp.buf.type_definition, "Goto Type Definition")
            map("<leader>ls", vim.lsp.buf.document_symbol, "LSP Symbols")
            map("<leader>lS", vim.lsp.buf.workspace_symbol, "LSP Workspace Symbols")
            --stylua: ignore end
        end

        map("gl", vim.diagnostic.open_float, "Open Diagnostic Float")
        map("<leader>la", vim.lsp.buf.code_action, "Code Action")
        map("<leader>lr", vim.lsp.buf.rename, "Rename all references")
        map("<leader>lf", function()
            vim.lsp.buf.format({ async = true })
        end, "Format")

        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if
            client
            and client:supports_method(
                vim.lsp.protocol.Methods.textDocument_documentHighlight
            )
        then
            local highlight_augroup =
                vim.api.nvim_create_augroup("lsp-highlight", { clear = false })

            autocmd({ "CursorHold", "CursorHoldI" }, {
                buffer = event.buf,
                group = highlight_augroup,
                callback = vim.lsp.buf.document_highlight,
            })

            autocmd({ "CursorMoved", "CursorMovedI" }, {
                buffer = event.buf,
                group = highlight_augroup,
                callback = vim.lsp.buf.clear_references,
            })

            autocmd("LspDetach", {
                group = vim.api.nvim_create_augroup(
                    "lsp-detach",
                    { clear = false }
                ),
                buffer = event.buf,
                callback = function(event2)
                    vim.lsp.buf.clear_references()
                    vim.api.nvim_clear_autocmds({
                        group = "lsp-highlight",
                        buffer = event2.buf,
                    })
                end,
            })
        end
    end,
})

-- Linting
autocmd({
    "BufEnter",
    "BufWritePost",
    "InsertLeave",
    "TextChanged",
}, {
    group = augroup("lint-attach", { clear = true }),
    callback = function()
        require("lint").try_lint()
    end,
})

-- Treesitter
autocmd("FileType", {
    group = augroup("treesitter_setup", { clear = true }),
    callback = function()
        pcall(vim.treesitter.start)
        vim.wo.foldmethod = "expr"
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.o.foldlevel = 99
    end,
})
