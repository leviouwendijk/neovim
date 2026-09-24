local funcs = require("config.funcs")

local builtin = funcs.require_or_nil("telescope.builtin", {
    message = "telescope.builtin missing; skipping telescope setup",
})

local telescope = funcs.require_or_nil("telescope", {
    message = "telescope missing; skipping telescope setup",
})

if not builtin or not telescope then
    return
end

-- local builtin = require("telescope.builtin")
-- local telescope = require("telescope")

telescope.setup({
    defaults = {
        file_ignore_patterns = { "%.git/", "%.build/" },
        preview = {
            treesitter = false,
        },
        vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden",
            "--glob", "!**/.build/**",
            "--glob", "!**/.git/**",
        },
    },
})

-- vim.keymap.set("n", "<leader>pf", function()
--     builtin.find_files({ hidden = true })
-- end, {})
-- vim.keymap.set("n", "<leader>py", ":Telescope yank_history<CR>")
-- vim.keymap.set("n", "<leader>ps", function()
--     builtin.grep_string({ search = vim.fn.input("Grep > "), hidden = true })
-- end)

-- require("telescope").load_extension("yank_history")
pcall(telescope.load_extension, "yank_history")
