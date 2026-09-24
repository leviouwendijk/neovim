vim.api.nvim_create_autocmd("FileType", {
    pattern = "checkhealth",
    callback = function(ev)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(ev.buf) then
                return
            end

            vim.bo[ev.buf].modifiable = true

            local repl = {
                ["✅"] = "✓",
                ["❌"] = "x",
                -- ["⚠️"] = "!",
                ["⚠️"] = "▲",
                ["ℹ️"] = "i",
            }

            for from, to in pairs(repl) do
                vim.cmd(string.format(
                    [[silent! keepjumps %%s/%s/%s/ge]],
                    vim.fn.escape(from, [[/\]]),
                    vim.fn.escape(to, [[/\]])
                ))
            end

            vim.bo[ev.buf].modifiable = false

            vim.treesitter.stop(ev.buf)
            vim.bo[ev.buf].syntax = "OFF"

            vim.opt_local.wrap = false
            vim.opt_local.linebreak = false
            vim.opt_local.breakindent = false
            vim.opt_local.showbreak = ""
            vim.opt_local.list = false
            vim.opt_local.colorcolumn = ""
        end)
    end,
})
