local acc = require("accessor")
local funcs = require("config.funcs")

local neorg = funcs.require_or_nil("neorg", {
    message = "neorg missing; skipping setup",
})

if not neorg then
    return
end

neorg.setup({
    load = {
        ["core.defaults"] = {}, -- Loads default behavior
        ["core.concealer"] = { -- Replaces 'core.norg.concealer'
            config = {
                icons = {
                    todo = {
                        cancelled = { icon = "❌" },
                        done = { icon = "✅" },
                        on_hold = { icon = "⏸️" },
                        urgent = { icon = "⚠️" }
                    }
                },
                dim_code_blocks = {
                    conceal = true,
                },
                icon_preset = "varied", -- Sets the icon style
            }
        },
        ["core.dirman"] = { -- Manages Neorg workspaces
            config = {
                workspaces = acc.paths.neorg.workspaces,
                -- workspaces = {
                --     writing = "~/myworkdir/neorg/writing",
                --     work = "~/myworkdir/neorg/work",
                --     personal = "~/myworkdir/neorg/personal",
                -- },
                index = "index.norg", -- Sets the root file
            }
        }
    }
})

function NeorgInjectMetadata()
    vim.cmd("Neorg inject-metadata")
end

vim.api.nvim_create_user_command(
    'Nim',
    NeorgInjectMetadata,
    { nargs = 0 }
)
