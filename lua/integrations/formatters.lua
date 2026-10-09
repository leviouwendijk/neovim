local funcs = require("config.funcs")
local conform = funcs.require_or_nil("conform", {
    message = "conform.nvim missing; non-Swift formatting unavailable",
})
if not conform then return end

local filetypes = {
    lua = { "stylua" },
    sh = { "shfmt" },
    bash = { "shfmt" },
}
if vim.g.nvim_tool_format_on_save == nil then
    vim.g.nvim_tool_format_on_save = false
end

conform.setup({
    formatters_by_ft = filetypes,
    format_on_save = function(bufnr)
        if vim.g.nvim_tool_format_on_save ~= true then return nil end
        if not filetypes[vim.bo[bufnr].filetype] then return nil end
        return { timeout_ms = 1000, lsp_format = "never" }
    end,
    default_format_opts = { lsp_format = "never" },
})

vim.api.nvim_create_user_command("ToolFormat", function()
    local bufnr = vim.api.nvim_get_current_buf()
    if not filetypes[vim.bo[bufnr].filetype] then
        funcs.safe_notify("No external formatter for this filetype",
            vim.log.levels.INFO)
        return
    end
    conform.format({
        bufnr = bufnr, async = false, timeout_ms = 3000,
        lsp_format = "never",
    })
end, { desc = "Format Lua/shell with StyLua/shfmt (not Swift)" })

vim.api.nvim_create_user_command("ToolFormatOnSave", function(opts)
    local arg = (opts.fargs[1] or "toggle"):lower()
    local value
    if arg == "on" then value = true
    elseif arg == "off" then value = false
    elseif arg == "toggle" then
        value = not (vim.g.nvim_tool_format_on_save == true)
    else
        funcs.safe_notify("Usage: :ToolFormatOnSave [on|off|toggle]",
            vim.log.levels.WARN)
        return
    end
    vim.g.nvim_tool_format_on_save = value
    funcs.safe_notify("Lua/shell format-on-save: " .. (value and "ON" or "OFF"))
end, { nargs = "?", desc = "Toggle non-Swift external format on save" })
