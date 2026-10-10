-- Netrw buffer refresh hooks: idempotent on FileType re-emission.
-- Neovim already updates the statusline on ordinary cursor movement;
-- explicit redrawstatus on every CursorMoved was redundant.
local group = vim.api.nvim_create_augroup("NetrwStatuslineRefresh", { clear = true })
local attached = {}

vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "netrw",
    callback = function(ev)
        if attached[ev.buf] then return end
        attached[ev.buf] = true

        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold" }, {
            group = group,
            buffer = ev.buf,
            callback = function() vim.cmd("redrawstatus") end,
        })
        vim.api.nvim_create_autocmd("BufWipeout", {
            group = group,
            buffer = ev.buf,
            once = true,
            callback = function() attached[ev.buf] = nil end,
        })
    end,
})
