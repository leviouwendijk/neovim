local funcs = require("config.funcs")
local acc = require("accessor")

local lsp_zero = funcs.require_or_nil("lsp-zero", {
    message = "lsp-zero missing; skipping ltex setup",
})

if not lsp_zero then
    return
end

-- Configure ltex
-- lspconfig.ltex.setup({ -- deprecated
vim.lsp.config('ltex', {
    on_attach = function(client, bufnr)
        -- Call the default lsp-zero on_attach
        lsp_zero.on_attach(client, bufnr)

        -- Additional keymaps or options for ltex
        local opts = { buffer = bufnr, remap = false }
        vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, opts)
        vim.keymap.set("n", "[d", function()
            vim.diagnostic.jump({ count = -1, float = true })
        end, opts)

        vim.keymap.set("n", "]d", function()
            vim.diagnostic.jump({ count = 1, float = true })
        end, opts)
    end,
    filetypes = { "markdown", "tex", "norg" }, -- Enable only for specific filetypes
    settings = {
        ltex = {
            language = acc.ltex.language,
            dictionary = acc.ltex.dictionary,
            disabledRules = acc.ltex.disabled_rules,
        },
    },
})

vim.lsp.enable('ltex')
