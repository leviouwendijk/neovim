local path = require("config.path")
local home = path.home

local M = {}

M.boot = {
    host_selections = {
        ["unknown"] = "minimal",
    },
    default_selection = "minimal",
}

M.bin = {
    sourcekit = { "sourcekit-lsp" },
    eclsp = {
        production = { "eclsp" },
    },
    bedrocks = "bedrocks",
    copier = "copier",
    trash = "trash",
    open = "open",
    pbcopy = "pbcopy",
    pbpaste = "pbpaste",
    python = "python3",
    -- python3_11 = "python3.11",
    swift = "swift",
    bash = "bash",
    node = "node",
    ec = {
        bin = "ec",
        id = {
            next = { "ec", "id", "next" },
        },
    }
}

M.paths = {
    home = home,
    neorg = {
        root = nil,
        workspaces = {},
    },
    writing_root = nil,
    pdf_output = nil,
    bedrocks = {
        root = nil,
    },
    clipboard_file = path.home_join(".clipboard"),
    log_file = path.home_join("neovim-debug-log.txt"),
    undodir = path.home_join(".vim", "undodir"),
}

M.treesitter = {
    ec = {
        repo = "https://github.com/leviouwendijk/tree-sitter-ec",
        branch = "master",
    },
}

M.ltex = {
    language = "en",
    dictionary = {
        en = { "om", "customword2", "( )" },
        nl = { "om", "( )" },
        he = { "דוגמה" },
    },
    disabled_rules = {
        en = {
            "WHITESPACE_RULE",
            "COMMA_PARENTHESIS_WHITESPACE",
            "OM"
        },
    },
}

return M
