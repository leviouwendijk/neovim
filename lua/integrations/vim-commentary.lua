-- vim.keymap.set("n", "gc", "<Plug>CommentaryLine", {})
-- vim.keymap.set("v", "gc", "<Plug>Commentary", {})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "ec",
    callback = function(ev)
        -- buffer-local options
        vim.bo[ev.buf].commentstring = "// %s"
        vim.bo[ev.buf].comments = "://"

        -- explicit format for tpope/vim-commentary
        vim.b[ev.buf].commentary_format = "// %s"
    end,
})

-- concatenation syntax
-- .conany
-- .conignore
-- .configure
-- .conselect
vim.filetype.add({
    extension = {
        conany     = "con",
        conignore  = "con",
        configure  = "con",
        conselect  = "con",
    },
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "con",
    callback = function(ev)
        vim.bo[ev.buf].commentstring = "# %s"
        -- 'comments' helps with formatting (gq) for single-line '#'
        vim.bo[ev.buf].comments = ":#"
        vim.b[ev.buf].commentary_format = "# %s"
    end,
})

-- Apple PKL syntax
vim.filetype.add({
    extension = {
        pkl     = "pkl",
    },
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "pkl",
    callback = function(ev)
        -- buffer-local options
        vim.bo[ev.buf].commentstring = "// %s"
        vim.bo[ev.buf].comments = "://"

        -- explicit format for tpope/vim-commentary
        vim.b[ev.buf].commentary_format = "// %s"

        vim.opt_local.foldenable = false
        vim.opt_local.foldmethod = "manual"
        -- vim.opt_local.foldexpr = "0"
    end,
})
