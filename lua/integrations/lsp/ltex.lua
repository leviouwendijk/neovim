-- Text diagnostics are independent of lsp-zero and completion.
local acc = require("accessor")

vim.lsp.config("ltex_plus", {
    filetypes = { "markdown", "tex", "norg" },
    settings = {
        ltex = {
            language = acc.ltex.language,
            dictionary = acc.ltex.dictionary,
            disabledRules = acc.ltex.disabled_rules,
        },
    },
})
vim.lsp.enable("ltex_plus")

