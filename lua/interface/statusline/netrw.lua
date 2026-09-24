-- Netrw-specific refreshes: attach only after a netrw buffer exists (no early netrw init)
vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function(ev)
        -- buffer-local light refresh hooks (safe; netrw reuses buffers)
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorMoved" }, {
            buffer = ev.buf,
            callback = function() vim.cmd("redrawstatus") end,
        })
    end,
})
