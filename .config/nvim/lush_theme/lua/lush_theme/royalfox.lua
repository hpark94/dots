local lush = require("lush")
local hsl = lush.hsl

---@diagnostic disable: undefined-global
local theme = lush(function(injected_functions)
    local sym = injected_functions.sym
    local p = {
        white_0 = hsl(30, 20, 97),
        white_1 = hsl(30, 20, 87),
        white_2 = hsl(30, 20, 77),
        gray_0 = hsl(275, 6, 50),
        gray_1 = hsl(275, 6, 40),
        black_0 = hsl(275, 6, 30),
        black_1 = hsl(275, 6, 20),
        red_0 = hsl(0, 45, 45),
        red_1 = hsl(0, 45, 35),
        red_bg_0 = hsl(0, 35, 85),
        red_bg_1 = hsl(0, 35, 75),
        orange_0 = hsl(23, 70, 45),
        orange_1 = hsl(23, 70, 35),
        orange_bg_0 = hsl(23, 70, 87),
        orange_bg_1 = hsl(23, 70, 77),
        yellow_0 = hsl(45, 80, 35),
        yellow_1 = hsl(45, 80, 25),
        yellow_bg_0 = hsl(45, 80, 85),
        yellow_bg_1 = hsl(45, 80, 75),
        green_0 = hsl(137, 35, 35),
        green_1 = hsl(137, 35, 30),
        green_bg_0 = hsl(137, 35, 85),
        green_bg_1 = hsl(137, 35, 75),
        cyan_0 = hsl(202, 43, 40),
        cyan_1 = hsl(202, 43, 30),
        cyan_bg_0 = hsl(202, 43, 85),
        cyan_bg_1 = hsl(202, 43, 75),
        blue_0 = hsl(231, 38, 48),
        blue_1 = hsl(231, 38, 38),
        blue_bg_0 = hsl(231, 38, 87),
        blue_bg_1 = hsl(231, 38, 77),
        violet_0 = hsl(263, 40, 42),
        violet_1 = hsl(263, 40, 32),
        violet_bg_0 = hsl(263, 40, 90),
        violet_bg_1 = hsl(263, 40, 80),
        magenta_0 = hsl(354, 50, 55),
        magenta_1 = hsl(340, 50, 45),
        magenta_bg_0 = hsl(340, 50, 87),
        magenta_bg_1 = hsl(340, 50, 77),
        red = hsl(0, 100, 50),
        yellow = hsl(50, 100, 50),
        green = hsl(100, 100, 40),
        blue = hsl(210, 100, 50),
        violet = hsl(290, 100, 50),
        gray = hsl(0, 0, 40),
    }
    return {
        ColorColumn({ fg = p.gray_1, bg = nil }), -- Columns set with 'colorcolumn'
        Conceal({ fg = p.gray_0, bg = nil }), -- Placeholder characters substituted for concealed text (see 'conceallevel')
        Cursor({ fg = p.white_0, bg = p.black_0 }), -- Character under the cursor
        CurSearch({ fg = Normal.fg, bg = p.green_bg_0 }), -- Highlighting a search pattern under the cursor (see 'hlsearch')
        lCursor({ Cursor }), -- Character under the cursor when |language-mapping| is used (see 'guicursor')
        CursorIM({ Cursor }), -- Like Cursor, but used when in IME mode |CursorIM|
        CursorColumn({ fg = p.gray_1, bg = nil }), -- Screen-column at the cursor, when 'cursorcolumn' is set.
        CursorLine({ fg = nil, bg = p.white_1 }), -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.
        Directory({ fg = p.cyan_1, bg = nil }), -- Directory names (and other special names in listings)
        Removed({ fg = nil, bg = p.red_bg_0 }), -- Removed line
        Added({ fg = nil, bg = p.green_bg_0 }), -- Added line
        Changed({ fg = nil, bg = p.yellow_bg_0 }), -- Changed line
        DiffAdd({ Added }), -- Diff mode: Added line |diff.txt|
        DiffDelete({ Removed }), -- Diff mode: Deleted line |diff.txt|
        DiffChange({ Changed }), -- Diff mode: Changed line |diff.txt|
        DiffText({ fg = nil, bg = p.blue_bg_0, gui = "italic" }), -- Diff mode: Changed text within a changed line |diff.txt|
        -- EndOfBuffer    { }, -- Filler lines (~) after the end of the buffer. By default, this is highlighted like |hl-NonText|.
        TermCursor({ Cursor }), -- Cursor in a focused terminal
        TermCursorNC({ fg = nil, bg = p.white_2 }), -- Cursor in an unfocused terminal
        ErrorMsg({ fg = p.red_0, gui = "italic" }), -- Error messages on the command line
        -- VertSplit      { }, -- Column separating vertically split windows
        -- Folded         { }, -- Line used for closed folds
        -- FoldColumn     { }, -- 'foldcolumn'
        -- SignColumn     { }, -- Column where |signs| are displayed
        IncSearch({ fg = Normal.fg, bg = p.green_bg_0 }), -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
        Substitute({ fg = Normal.fg, bg = p.yellow_bg_0 }), -- |:substitute| replacement text highlighting
        LineNr({ fg = p.gray_0, bg = nil }), -- Line number for ":number" and ":#" commands, and when 'number' or 'relativenumber' option is set.
        LineNrAbove({ LineNr }), -- Line number for when the 'relativenumber' option is set, above the cursor line
        LineNrBelow({ LineNr }), -- Line number for when the 'relativenumber' option is set, below the cursor line
        CursorLineNr({ fg = p.black_0, bg = CursorLine.bg, gui = "bold" }), -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
        -- CursorLineFold { }, -- Like FoldColumn when 'cursorline' is set for the cursor line
        -- CursorLineSign { }, -- Like SignColumn when 'cursorline' is set for the cursor line
        MatchParen({ fg = p.cyan_1, bg = p.cyan_bg_1 }), -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|
        ModeMsg({ fg = p.green_0, bg = nil }), -- 'showmode' message (e.g., "-- INSERT -- ")
        MsgArea({ fg = p.gray_1, bg = nil }), -- Area for messages and cmdline
        MsgSeparator({ MsgArea }), -- Separator for scrolled messages, `msgsep` flag of 'display'
        MoreMsg({ fg = p.cyan_1, bg = nil }), -- |more-prompt|
        NonText({ fg = p.gray_0, bg = nil }), -- '@' at the end of the window, characters from 'showbreak' and other characters that do not really exist in the text (e.g., ">" displayed when a double-wide character doesn't fit at the end of the line). See also |hl-EndOfBuffer|.
        Normal({ fg = p.black_0, bg = p.white_0 }), -- Normal text
        NormalFloat({ fg = nil, bg = p.white_0 }), -- Normal text in floating windows.
        FloatBorder({ fg = p.cyan_1, bg = nil }), -- Border of floating windows.
        FloatTitle({ fg = p.cyan_1, bg = nil }), -- Title of floating windows.
        NormalNC({ Normal }), -- normal text in non-current windows
        Pmenu({ fg = Normal.fg, bg = p.white_0 }), -- Popup menu: Normal item.
        PmenuSel({ fg = Pmenu.fg.darken(20), bg = Pmenu.bg.darken(15), gui = "bold" }), -- Popup menu: Selected item.
        PmenuKind({ fg = p.cyan_0, bg = Pmenu.bg }), -- Popup menu: Normal item "kind"
        PmenuKindSel({ fg = PmenuKind.fg.darken(20), bg = PmenuSel.bg }), -- Popup menu: Selected item "kind"
        PmenuExtra({ Pmenu, gui = "italic" }), -- Popup menu: Normal item "extra text"
        PmenuExtraSel({ PmenuSel, gui = "italic,bold" }), -- Popup menu: Selected item "extra text"
        -- PmenuSbar      { }, -- Popup menu: Scrollbar.
        -- PmenuThumb     { }, -- Popup menu: Thumb of the scrollbar.
        Question({ fg = p.cyan_0, bg = nil }), -- |hit-enter| prompt and yes/no questions
        QuickFixLine({ fg = p.cyan_0, bg = nil }), -- Current |quickfix| item in the quickfix window. Combined with |hl-CursorLine| when the cursor is there.
        Search({ fg = Normal.fg, bg = p.yellow_bg_0 }), -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
        SpecialKey({ fg = p.gray_0, bg = nil }), -- Unprintable characters: text displayed differently from what it really is. But not 'listchars' whitespace. |hl-Whitespace|
        SpellBad({ fg = nil, bg = nil, sp = p.red, gui = "underline" }), -- Word that is not recognized by the spellchecker. |spell| Combined with the highlighting used otherwise.
        SpellCap({ fg = nil, bg = nil, sp = p.gray, gui = "underline" }), -- Word that should start with a capital. |spell| Combined with the highlighting used otherwise.
        SpellLocal({ fg = nil, bg = nil, sp = p.blue, gui = "underline" }), -- Word that is recognized by the spellchecker as one that is used in another region. |spell| Combined with the highlighting used otherwise.
        SpellRare({ fg = nil, bg = nil, sp = p.violet, gui = "underline" }), -- Word that is recognized by the spellchecker as one that is hardly ever used. |spell| Combined with the highlighting used otherwise.
        StatusLine({ fg = nil, bg = p.white_1 }), -- Status line of current window
        StatusLineNC({ StatusLine }), -- Status lines of not-current windows. Note: If this is equal to "StatusLine" Vim will use "^^^" in the status line of the current window.
        -- TabLine        { }, -- Tab pages line, not active tab page label
        -- TabLineFill    { }, -- Tab pages line, where there are no labels
        -- TabLineSel     { }, -- Tab pages line, active tab page label
        Title({ fg = p.cyan_1, bg = nil, gui = "bold" }), -- Titles for output from ":set all", ":autocmd" etc.
        Visual({ fg = p.black_0, bg = p.cyan_bg_0 }), -- Visual mode selection
        -- VisualNOS      { }, -- Visual mode selection when vim is "Not Owning the Selection".
        WarningMsg({ fg = p.yellow_0, bg = nil }), -- Warning messages
        Whitespace({ fg = p.gray_0, bg = nil }), -- "nbsp", "space", "tab" and "trail" in 'listchars'
        Winseparator({ fg = p.black_0, bg = nil }), -- Separator between window splits. Inherts from |hl-VertSplit| by default, which it will replace eventually.
        WildMenu({ PmenuSel }), -- Current match in 'wildmenu' completion
        -- WinBar         { }, -- Window bar of current window
        -- WinBarNC       { }, -- Window bar of not-current windows

        -- Common vim syntax groups used for all kinds of code and markup.
        -- Commented-out groups should chain up to their preferred (*) group
        -- by default.
        --
        -- See :h group-name
        --
        -- Uncomment and edit if you want more specific syntax highlighting.

        Comment({ fg = p.gray_0, bg = nil, gui = "italic" }), -- Any comment

        Constant({ fg = p.yellow_0, bg = nil }), -- (*) Any constant
        String({ fg = p.green_0, bg = nil, gui = "italic" }), --   A string constant: "this is a string"
        Character({ fg = p.violet_0, bg = nil }), --   A character constant: 'c', '\n'
        Number({ fg = p.orange_0, bg = nil }), --   A number constant: 234, 0xff
        Boolean({ fg = p.orange_0, bg = nil }), --   A boolean constant: TRUE, false
        Float({ fg = p.orange_0, bg = nil }), --   A floating point constant: 2.3e10

        Identifier({ fg = p.blue_1, bg = nil }), -- (*) Any variable name
        Function({ fg = p.cyan_0, bg = nil }), --   Function name (also: methods for classes)

        Statement({ fg = p.black_0, bg = nil, gui = "bold" }), -- (*) Any statement
        Conditional({ fg = p.magenta_0, bg = nil, gui = "italic" }), --   if, then, else, endif, switch, etc.
        Repeat({ Conditional }), --   for, do, while, etc.
        Label({ Conditional }), --   case, default, etc.
        Operator({ fg = p.blue_0, bg = nil }), --   "sizeof", "+", "*", etc.
        Keyword({ fg = p.magenta_0, bg = nil }), --   any other keyword
        Exception({ fg = p.violet_0, bg = nil, gui = "italic" }), --   try, catch, throw

        PreProc({ fg = p.red_0, bg = nil }), -- (*) Generic Preprocessor
        Include({ PreProc }), --   Preprocessor #include
        Define({ PreProc }), --   Preprocessor #define
        Macro({ PreProc }), --   Same as Define
        PreCondit({ PreProc }), --   Preprocessor #if, #else, #endif, etc.

        Type({ fg = p.magenta_1, bg = nil }), -- (*) int, long, char, etc.
        StorageClass({ Type }), --   static, register, volatile, etc.
        Structure({ Type }), --   struct, union, enum, etc.
        Typedef({ Type }), --   A typedef

        Special({ fg = p.cyan_0, bg = nil }), -- (*) Any special symbol
        SpecialChar({ Special }), --   Special character in a constant
        Tag({ Special }), --   You can use CTRL-] on this
        Delimiter({ fg = p.violet_0, bg = nil }), --   Character that needs attention
        SpecialComment({ Special }), --   Special things inside a comment (e.g. '\n')
        Debug({ fg = p.blue_0, bg = nil, gui = "italic" }), --   Debugging statements

        Underlined({ fg = nil, bg = nil, gui = "underline" }), -- Text that stands out, HTML links
        Ignore({ fg = nil, bg = nil }), -- Left blank, hidden |hl-Ignore| (NOTE: May be invisible here in template)
        Error({ fg = p.black_0, bg = p.red_bg_0, gui = "bold" }), -- Any erroneous construct
        Todo({ fg = p.black_0, bg = p.yellow_bg_0, gui = "bold" }), -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX

        -- These groups are for the native LSP client and diagnostic system. Some
        -- other LSP clients may use these groups, or use their own. Consult your
        -- LSP client's documentation.

        -- See :h lsp-highlight, some groups may not be listed, submit a PR fix to lush-template!
        --
        LspReferenceText({ fg = p.black_0, bg = p.blue_bg_0, gui = "underline" }), -- Used for highlighting "text" references
        LspReferenceRead({ LspReferenceText, fg = p.blue_1 }), -- Used for highlighting "read" references
        LspReferenceWrite({ LspReferenceText, fg = p.green_1 }), -- Used for highlighting "write" references
        LspCodeLens({ fg = p.gray_1, bg = nil, gui = "italic" }), -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
        LspCodeLensSeparator({ LspCodeLens }), -- Used to color the seperator between two or more code lens.
        LspSignatureActiveParameter({ fg = p.black_0, bg = p.cyan_bg_0 }), -- Used to highlight the active parameter in the signature help. See |vim.lsp.handlers.signature_help()|.

        -- See :h diagnostic-highlights, some groups may not be listed, submit a PR fix to lush-template!
        DiagnosticError({ fg = p.red_0, bg = nil }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
        DiagnosticWarn({ fg = p.yellow_0, bg = nil }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
        DiagnosticInfo({ fg = p.gray_1, bg = nil }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
        DiagnosticHint({ fg = p.cyan_0, bg = nil }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
        DiagnosticOk({ fg = p.green_0, bg = nil }), -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
        DiagnosticVirtualTextError({ DiagnosticError }), -- Used for "Error" diagnostic virtual text.
        DiagnosticVirtualTextWarn({ DiagnosticWarn }), -- Used for "Warn" diagnostic virtual text.
        DiagnosticVirtualTextInfo({ DiagnosticInfo }), -- Used for "Info" diagnostic virtual text.
        DiagnosticVirtualTextHint({ DiagnosticHint }), -- Used for "Hint" diagnostic virtual text.
        DiagnosticVirtualTextOk({ DiagnosticOk }), -- Used for "Ok" diagnostic virtual text.
        DiagnosticUnderlineError({ gui = "underline", sp = DiagnosticError.fg }), -- Used to underline "Error" diagnostics.
        DiagnosticUnderlineWarn({ gui = "underline", sp = DiagnosticWarn.fg }), -- Used to underline "Warn" diagnostics.
        DiagnosticUnderlineInfo({ gui = "underline", sp = DiagnosticInfo.fg }), -- Used to underline "Info" diagnostics.
        DiagnosticUnderlineHint({ gui = "underline", sp = DiagnosticHint.fg }), -- Used to underline "Hint" diagnostics.
        DiagnosticUnderlineOk({ gui = "underline", sp = DiagnosticOk.fg }), -- Used to underline "Ok" diagnostics.
        DiagnosticFloatingError({ DiagnosticError }), -- Used to color "Error" diagnostic messages in diagnostics float. See |vim.diagnostic.open_float()|
        DiagnosticFloatingWarn({ DiagnosticWarn }), -- Used to color "Warn" diagnostic messages in diagnostics float.
        DiagnosticFloatingInfo({ DiagnosticInfo }), -- Used to color "Info" diagnostic messages in diagnostics float.
        DiagnosticFloatingHint({ DiagnosticHint }), -- Used to color "Hint" diagnostic messages in diagnostics float.
        DiagnosticFloatingOk({ DiagnosticOk }), -- Used to color "Ok" diagnostic messages in diagnostics float.
        DiagnosticSignError({ DiagnosticError }), -- Used for "Error" signs in sign column.
        DiagnosticSignWarn({ DiagnosticWarn }), -- Used for "Warn" signs in sign column.
        DiagnosticSignInfo({ DiagnosticInfo }), -- Used for "Info" signs in sign column.
        DiagnosticSignHint({ DiagnosticHint }), -- Used for "Hint" signs in sign column.
        DiagnosticSignOk({ DiagnosticOk }), -- Used for "Ok" signs in sign column.

        -- Tree-Sitter syntax groups.
        --
        -- See :h treesitter-highlight-groups, some groups may not be listed,
        -- submit a PR fix to lush-template!
        --
        -- Tree-Sitter groups are defined with an "@" symbol, which must be
        -- specially handled to be valid lua code, we do this via the special
        -- sym function. The following are all valid ways to call the sym function,
        -- for more details see https://www.lua.org/pil/5.html
        --
        -- sym("@text.literal")
        -- sym('@text.literal')
        -- sym"@text.literal"
        -- sym'@text.literal'
        --
        -- For more information see https://github.com/rktjmp/lush.nvim/issues/109

        sym("@text.literal")({ Comment }), -- Comment
        sym("@text.reference")({ Identifier }), -- Identifier
        sym("@text.title")({ Title }), -- Title
        sym("@text.uri")({ Underlined }), -- Underlined
        sym("@text.underline")({ Underlined }), -- Underlined
        sym("@text.todo")({ Todo }), -- Todo
        sym("@comment")({ Comment }), -- Comment
        sym("@punctuation")({ Special }), -- Delimiter
        sym("@constant")({ Constant }), -- Constant
        sym("@constant.builtin")({ Special }), -- Special
        sym("@constant.macro")({ Define }), -- Define
        sym("@define")({ Define }), -- Define
        sym("@macro")({ Macro }), -- Macro
        sym("@string")({ String }), -- String
        sym("@string.escape")({ SpecialChar }), -- SpecialChar
        sym("@string.special")({ SpecialChar }), -- SpecialChar
        sym("@character")({ Character }), -- Character
        sym("@character.special")({ SpecialChar }), -- SpecialChar
        sym("@number")({ Number }), -- Number
        sym("@boolean")({ Boolean }), -- Boolean
        sym("@float")({ Float }), -- Float
        sym("@function")({ Function }), -- Function
        sym("@function.builtin")({ Function }), -- Special
        sym("@function.macro")({ Function }), -- Macro
        sym("@parameter")({ Identifier }), -- Identifier
        sym("@method")({ Function }), -- Function
        sym("@field")({ Identifier }), -- Identifier
        sym("@property")({ Identifier }), -- Identifier
        sym("@constructor")({ Special }), -- Special
        sym("@conditional")({ Conditional }), -- Conditional
        sym("@repeat")({ Repeat }), -- Repeat
        sym("@label")({ Label }), -- Label
        sym("@operator")({ Operator }), -- Operator
        sym("@keyword")({ Keyword }), -- Keyword
        sym("@exception")({ Exception }), -- Exception
        sym("@variable")({ Identifier }), -- Identifier
        sym("@type")({ Type }), -- Type
        sym("@type.definition")({ Typedef }), -- Typedef
        sym("@storageclass")({ StorageClass }), -- StorageClass
        sym("@structure")({ Structure }), -- Structure
        sym("@namespace")({ Identifier }), -- Identifier
        sym("@include")({ Include }), -- Include
        sym("@preproc")({ PreProc }), -- PreProc
        sym("@debug")({ Debug }), -- Debug
        sym("@tag")({ Tag }), -- Tag
        sym("@markup.link")({ Underlined, fg = p.blue_0 }),
        sym("@markup.italic")({ fg = p.green_0, bg = nil, gui = "italic" }),
        sym("@markup.strong")({ fg = p.magenta_0, bg = nil, gui = "bold" }),
        sym("@diff.minus")({ DiffDelete }),
        sym("@diff.plus")({ DiffAdd }),
        sym("@diff.delta")({ DiffChange }),

        GitSignsAdd({ fg = p.green, bg = nil }),
        GitSignsAddLn({ GitSignsAdd }),
        GitSignsAddInline({ GitSignsAdd }),
        GitSignsChange({ fg = p.yellow, bg = nil }),
        GitSignsChangeLn(GitSignsChange),
        GitSignsChangeInline(GitSignsChange),
        GitSignsDelete({ fg = p.red, bg = nil }),
        GitSignsDeleteLn({ GitSignsDelete }),
        GitSignsDeleteInline({ GitSignsDelete }),
        GitSignsUntracked({ fg = p.blue, bg = nil }),
        GitSignsUntrackedLn({ GitSignsUntracked }),
        GitSignsUntrackedInline({ GitSignsUntracked }),

        NotifyDEBUGBorder({ fg = p.cyan_0, bg = nil }),
        NotifyDEBUGIcon({ NotifyDEBUGBorder }),
        NotifyDEBUGTitle({ NotifyDEBUGBorder }),
        NotifyERRORBorder({ fg = p.red_0, bg = nil }),
        NotifyERRORIcon({ NotifyERRORBorder }),
        NotifyERRORTitle({ NotifyERRORBorder }),
        NotifyINFOBorder({ fg = p.blue_0, bg = nil }),
        NotifyINFOIcon({ NotifyINFOBorder }),
        NotifyINFOTitle({ NotifyINFOBorder }),
        NotifyTRACEBorder({ fg = p.green_0, bg = nil }),
        NotifyTRACEIcon({ NotifyTRACEBorder }),
        NotifyTRACETitle({ NotifyTRACEBorder }),
        NotifyWARNBorder({ fg = p.yellow_0, bg = nil }),
        NotifyWARNIcon({ NotifyWARNBorder }),
        NotifyWARNTitle({ NotifyWARNBorder }),

        BlinkCmpKind({ fg = p.cyan_0 }),

        MiniStatuslineDevinfo({ fg = p.cyan_0, bg = p.white_1 }),
        MiniStatuslineFileinfo({ MiniStatuslineDevinfo }),
        MiniStatuslineFilename({ fg = p.black_0, bg = p.white_0 }),
        MiniStatuslineInactive({ StatusLineNC }),
        MiniStatuslineModeCommand({ fg = p.white_0, bg = p.blue_0, gui = "bold" }),
        MiniStatuslineModeInsert({ fg = p.white_0, bg = p.green_0, gui = "bold" }),
        MiniStatuslineModeNormal({ fg = p.white_0, bg = p.cyan_0, gui = "bold" }),
        MiniStatuslineModeVisual({ fg = p.white_0, bg = p.magenta_0, gui = "bold" }),
        MiniStatuslineModeOther({ fg = p.white_0, bg = p.black_0, gui = "bold" }),
        MiniStatuslineModeReplace({ fg = p.white_0, bg = p.violet_0, gui = "bold" }),

        RenderMarkdownBullet({ fg = p.cyan_0, bg = nil }),
        RenderMarkdownChecked({ DiagnosticOk }),
        RenderMarkdownUnchecked({ DiagnosticWarn }),
        RenderMarkdownCode({ fg = nil, bg = p.violet_bg_0 }),
        RenderMarkdownCodeInline({ fg = p.violet_0, bg = p.violet_bg_0 }),
        RenderMarkdownDash({ RenderMarkdownBullet }),
        RenderMarkdownDash({ RenderMarkdownBullet }),
        RenderMarkdownH1({ fg = p.red_0, bg = nil }),
        RenderMarkdownH1Bg({ fg = p.black_0, bg = p.red_bg_0, gui = "bold" }),
        RenderMarkdownH2({ fg = p.yellow_0, bg = nil }),
        RenderMarkdownH2Bg({ fg = p.black_0, bg = p.yellow_bg_0, gui = "bold" }),
        RenderMarkdownH3({ fg = p.cyan_0, bg = nil }),
        RenderMarkdownH3Bg({ fg = p.black_0, bg = p.cyan_bg_0, gui = "bold" }),
        RenderMarkdownH4({ fg = p.orange_0, bg = nil }),
        RenderMarkdownH4Bg({ fg = p.black_0, bg = p.orange_bg_0, gui = "bold" }),
        RenderMarkdownH5({ fg = p.green_0, bg = nil }),
        RenderMarkdownH5Bg({ fg = p.black_0, bg = p.green_bg_0, gui = "bold" }),
        RenderMarkdownH6({ fg = p.blue_0, bg = nil }),
        RenderMarkdownH6Bg({ fg = p.black_0, bg = p.blue_bg_0, gui = "bold" }),
        RenderMarkdownTodo({ Todo }),
    }
end)

-- Return our parsed theme for extension or use elsewhere.
return theme

-- vi:nowrap
