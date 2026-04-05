local path = require("config.path")

local M = {}

local eclsp_bin = path.home_join("sbm-bin", "eclsp")
local neorg_root = path.home_join("myworkdir", "neorg")
local writing_root = path.home_join("myworkdir", "writing")
local bedrocks_root = path.home_join("myworkdir", "ctxw")

M.boot = {
    host_selections = {
        ["my-hostname"] = "full",
        ["my-hostname.local"] = "full",
        ["laptop"] = "light",
    },
}

M.bin = {
    -- Optional platform overrides:
    --
    -- Linux / Wayland:
    -- open = "xdg-open",
    -- pbcopy = "wl-copy",
    -- pbpaste = "wl-paste",
    -- trash = "trash-put",
    --
    -- Linux / X11:
    -- open = "xdg-open",
    -- pbcopy = "xclip",
    -- pbpaste = "xclip -o -selection clipboard", -- multi string not yet supported
    -- trash = "trash-put",

    sourcekit = {
        "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
    },
    eclsp = {
        production = {
            eclsp_bin,
        },
        debug = function(logfile)
            logfile = logfile or "/tmp/eclsp.stderr"

            return {
                "sh",
                "-c",
                eclsp_bin .. " 2>>" .. logfile,
            }
        end,
    },
}

M.paths = {
    home = path.home,
    neorg = {
        root = neorg_root,
        workspaces = {
            writing = path.join(neorg_root, "writing"),
            work = path.join(neorg_root, "work"),
            personal = path.join(neorg_root, "personal"),
        },
    },
    writing_root = writing_root,
    pdf_output = path.home_join("myworkdir", "pdf_output"),
    bedrocks = {
        root = bedrocks_root,
    },
}

return M
