-- local notifier = require("utils.notify")
-- local acc = require("accessor")
local funcs = require("config.funcs")

local get_output = funcs.once_require("extensions.output")
local get_shell = funcs.once_require_or_nil("extensions.shell", {
    message = "extensions.shell missing; toggle unavailable",
})
local get_ec_id = funcs.once_require_or_nil("extensions.ec-id", {
    message = "extensions.ec-id missing; EC id action unavailable",
})
local get_ec_template = funcs.once_require_or_nil("extensions.ec-template", {
    message = "extensions.ec-template missing; EC template action unavailable",
})
local get_telescope_builtin = funcs.once_require_or_nil("telescope.builtin", {
    message = "telescope.builtin missing; Telescope file search unavailable",
})
local get_telescope = funcs.once_require_or_nil("telescope", {
    message = "telescope missing; Telescope extension unavailable",
})
local get_treesitter_context = funcs.once_require_or_nil("treesitter-context", {
    message = "treesitter-context missing; toggle unavailable",
})

-- core remaps
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.keymap.set("n", "yat", ": % y <CR>")

-- file-based remaps
vim.keymap.set("n", "<leader>of", funcs.open_current_file, {
    desc = "Open current file externally",
    silent = true,
})
vim.keymap.set("n", "<leader>op", funcs.open_current_path)
vim.keymap.set("n", "<leader>cf", funcs.copy_filepath_to_clipboard)

vim.keymap.set("i", "<C-c>", "<Esc>") -- shortcut control+c for escape (insert mode)
vim.keymap.set("n", "<leader><leader>", function()
    vim.cmd("so")
end)
vim.keymap.set("n", "<C-a>", funcs.select_whole_buffer)
vim.keymap.set("n", "<leader>goo", funcs.open_cwd, {
    desc = "Open current working directory externally",
    silent = true,
})
vim.keymap.set("x", "<leader>p", [["_dP]]) -- Deletes the selected text (_d) and then pastes (P) the deleted text before the cursor. This effectively swaps the selected text with the text below it.
vim.keymap.set({"n", "v"}, "<leader>d", [["_d]]) -- in either Normal or Visual mode will delete the selected text and place it in the default register, allowing it to be pasted elsewhere using the standard paste command (p or P).
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]]) -- search and replace function
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true }) -- make exec 

-- remaining primagen copies
vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")
vim.keymap.set("n", "<leader>dirswift", funcs.insert_swift_dirs)
-- vim.keymap.set("n", "<leader>rf", ":! %<CR>")

vim.keymap.set("n", "<leader>goy", ":Goyo<CR>")
-- vim.keymap.set("n", "<leader>gs", vim.cmd.Git);
vim.keymap.set("n", "<leader>gs", "<cmd>Git<CR>", {
    desc = "Git status",
})
vim.keymap.set("n", "<leader>gh", ":Gitsigns preview_hunk<CR>", {})
vim.keymap.set("n", "<leader>gb", ":Gitsigns toggle_current_line_blame<CR>", {})
vim.keymap.set("n", "<leader>see", ":MarkdownPreview<CR>")
vim.keymap.set("n", "<leader>lime", ":Limelight<CR>")
vim.keymap.set("n", "<leader>tc", function()
    local context = get_treesitter_context()
    if not context or type(context.toggle) ~= "function" then
        return
    end

    context.toggle()
end, {
        desc = "Toggle Treesitter Context",
        silent = true
    }
)
vim.keymap.set("n", "<leader>rs",
    function()
        local shell = get_shell()
        if not shell then
            return
        end

        shell.toggle()
    end, {
        desc = "Toggle shell"
    }
)

-- get diagnosis for error under cursor
vim.keymap.set('n','<leader>ds', function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]-1
    for _, d in ipairs(vim.diagnostic.get(0, { lnum = lnum })) do
        print(string.format("[%s] %s", d.source or "?", d.message))
    end
end, { desc = "Diag source under cursor" })


-- ========================================================

-- yanky

-- destroys native register syncing:
-- vim.keymap.set({"n","x"}, "p", "<Plug>(YankyPutAfter)")
-- vim.keymap.set({"n","x"}, "P", "<Plug>(YankyPutBefore)")

vim.keymap.set({ "n", "x" }, "gp", "<Plug>(YankyPutAfter)")
vim.keymap.set({ "n", "x" }, "gP", "<Plug>(YankyPutBefore)")

vim.keymap.set({ "n", "x" }, "<leader>gp", "<Plug>(YankyGPutAfter)")
vim.keymap.set({ "n", "x" }, "<leader>gP", "<Plug>(YankyGPutBefore)")

vim.keymap.set("n", "<c-p>", "<Plug>(YankyPreviousEntry)")
vim.keymap.set("n", "<c-n>", "<Plug>(YankyNextEntry)")

-- ========================================================

-- ec
vim.keymap.set("n", "<leader>neid", function()
    local ec_id = get_ec_id()
    if not ec_id then
        return
    end

    ec_id.next("entry")
end, {
    desc = "Insert next ENTRY id at cursor",
    silent = true,
})

vim.keymap.set("n", "<leader>nereg", function()
    local ec_template = get_ec_template()
    if not ec_template then
        return
    end

    ec_template.insert("mirrored", "entry")
end, {
    desc = "Insert EC mirrored entry template",
    silent = true,
})

-- ========================================================

-- telescope
vim.keymap.set("n", "<leader>pf", function()
    local builtin = get_telescope_builtin()
    if not builtin then
        return
    end

    builtin.find_files({
        hidden = true,
    })
end, {
    desc = "Find files",
})

vim.keymap.set("n", "<leader>ps", function()
    local builtin = get_telescope_builtin()
    if not builtin then
        return
    end

    builtin.grep_string({
        search = vim.fn.input("Grep > "),
        hidden = true,
    })
end, {
    desc = "Grep string",
})

vim.keymap.set("n", "<leader>py", function()
    local telescope = get_telescope()
    if not telescope or not telescope.extensions or not telescope.extensions.yank_history then
        funcs.safe_notify("telescope yank_history unavailable", vim.log.levels.WARN)
        return
    end

    telescope.extensions.yank_history.yank_history()
end, {
    desc = "Yank history",
})

-- ========================================================

-- output-cmd

vim.keymap.set(
    "n",
    "<leader>ou",
    function()
        get_output().toggle()
    end, {
        desc = "Output: toggle view (default mode)"
    }
)

vim.keymap.set(
    "n",
    "<leader>gof",
    function()
        get_output().toggle("float")
    end, {
        desc = "Output: toggle float"
    }
)

vim.keymap.set(
    "n",
    "<leader>gou",
    function()
        get_output().toggle("split")
    end, {
        desc = "Output: toggle split"
    }
)

vim.keymap.set(
    "n",
    "<leader>goc",
    function()
        get_output().clear()
    end, {
        desc = "Output: clear buffer"
    }
)

vim.keymap.set(
    "n",
    "<leader>gopy",
    function()
        local acc = require("accessor")

        get_output().run_file_in_split(acc.bin.python, funcs.current_file(), 0)
    end, {
        desc = "Run current file (Python) → Output split"
    }
)

vim.keymap.set(
    "n",
    "<leader>gos",
    function()
        local acc = require("accessor")

        get_output().run_file_in_split(acc.bin.swift, funcs.current_file(), 0)
    end, {
        desc = "Run current file (Swift) → Output split"
    }
)

vim.keymap.set(
    "n",
    "<leader>gopt",
    function()
        local acc = require("accessor")

        get_output().run_file_in_float(
            acc.bin.python,
            funcs.current_file(),
            0,
            {
                width = 0.9,
                height = 0.6
            }
        )
    end, {
        desc = "Run current file (Python) → Float preview"
    }
)

vim.keymap.set(
    "n",
    "<leader>got",
    function()
        local acc = require("accessor")

        get_output().run_file_in_float(
            acc.bin.swift,
            funcs.current_file(),
            0,
            {
                width = 0.9,
                height = 0.6
            }
        )
    end, {
        desc = "Run current file (Swift) → Float preview"
    }
)

-- ========================================================

-- others, still inside after/plugin/.. :
-- > harpoon
-- > neoscroll

-- ========================================================
