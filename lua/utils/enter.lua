local M = {}

-- util: optionally auto-press <CR> to kill any pending "Press ENTER"
function M.press_enter()
    local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    vim.api.nvim_feedkeys(cr, "n", false)
end

return M
