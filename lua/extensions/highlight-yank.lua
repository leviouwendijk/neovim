-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
local performance_mode = true
local debounce_timer = nil

vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        -- adding guard:
        if vim.v.event.operator ~= "y" then
            return
        end
        -- vim.highlight.on_yank()
        vim.hl.on_yank()

        if debounce_timer then
            debounce_timer:stop()
        end

        debounce_timer = vim.defer_fn(function()
            if performance_mode then
                vim.cmd('echo "yanked"')
            else
                local reg_info = vim.fn.getreginfo('"')
                local yanked_text = reg_info.regcontents or {}
                local line_count = #yanked_text
                vim.cmd('echo "' .. line_count .. ' lines yanked"')
            end
        end, 50) -- debounce 50 ms to avoid double triggers
    end,
})
