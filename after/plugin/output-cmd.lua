local funcs = require("config.funcs")
local acc = require("accessor")

local output = funcs.require_or_nil("extensions.output", {
    message = "extensions.output missing; skipping output commands",
})

if not output then
    return
end

output.setup(
    {
        default_mode = "float",
        name = "[output]",
        float = {
            width = 0.9,
            height = 0.6,
            title = "Output",
            border = "rounded"
        },
    }
)

vim.api.nvim_create_user_command(
    "OutputRunSplit",
    function(opts)
        local cmd = opts.fargs[1]
        output.run_file_in_split(cmd, vim.fn.expand("%:p"), 0)
    end, {
        nargs = 1,
        complete = function()
            return {
                acc.bin.python,
                acc.bin.swift,
                acc.bin.bash,
                acc.bin.node,
            }
        end
    }
)

vim.api.nvim_create_user_command(
    "OutputRunFloat",
    function(opts)
        local cmd = opts.fargs[1]
        output.run_file_in_float(cmd, vim.fn.expand("%:p"), 0)
    end, {
        nargs = 1,
        complete = function()
            return {
                acc.bin.python,
                acc.bin.swift,
                acc.bin.bash,
                acc.bin.node,
            }
        end
    }
)

vim.api.nvim_create_user_command(
    "OutputToggle",
    function(opts)
        output.toggle(opts.args ~= "" and opts.args or nil) -- args: "float" | "split" | ""
    end, {
        nargs = "?",
        complete = function()
            return { "float", "split" }
        end
    }
)

-- -- toggle in whatever the default mode is
-- vim.keymap.set(
--     "n",
--     "<leader>ou",
--     function()
--         output.toggle()  -- uses config.default_mode
--     end, {
--         desc = "Output: toggle view (default mode)"
--     }
-- )

-- -- optional: force-mode toggles if you want both
-- vim.keymap.set(
--     "n",
--     "<leader>gof",
--     function()
--         output.toggle("float")
--     end, {
--         desc = "Output: toggle float"
--     }
-- )

-- vim.keymap.set(
--     "n",
--     "<leader>gou",
--     function()
--         output.toggle("split")
--     end, {
--         desc = "Output: toggle split"
--     }
-- )

-- -- quick clear
-- vim.keymap.set(
--     "n",
--     "<leader>goc",
--     function()
--         output.clear()
--     end, {
--         desc = "Output: clear buffer (default mode)"
--     }
-- )

-- -- Split output (existing keys)
-- vim.keymap.set(
--     "n",
--     "<leader>gopy",
--     function()
--         output.run_file_in_split(acc.bin.python, vim.fn.expand("%:p"), 0)
--     end, {
--         desc = "Run current file (Python) → Output buffer (split)"
--     }
-- )

-- vim.keymap.set(
--     "n",
--     "<leader>gos",
--     function()
--         output.run_file_in_split(acc.bin.swift, vim.fn.expand("%:p"), 0)
--     end, {
--         desc = "Run current file (Swift) → Output buffer (split)"
--     }
-- )

-- -- plenary window float
-- vim.keymap.set(
--     "n",
--     "<leader>gopt",
--     function()
--         output.run_file_in_float(
--             acc.bin.python,
--             vim.fn.expand("%:p"),
--             0,
--             {
--                 width = 0.9,
--                 height = 0.6
--             }
--         )
--     end, {
--         desc = "Run current file (Python) → Float preview"
--     }
-- )

-- vim.keymap.set(
--     "n",
--     "<leader>got",
--     function()
--         output.run_file_in_float(
--             acc.bin.swift,
--             vim.fn.expand("%:p"),
--             0,
--             {
--                 width = 0.9,
--                 height = 0.6
--             }
--         )
--     end, {
--         desc = "Run current file (Swift) → Float preview"
--     }
-- )

