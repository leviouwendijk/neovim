local diagnostics =
    require("integrations.lsp.interaction.diagnostics")
local diagnostic_copy =
    require("integrations.lsp.interaction.diagnostic-copy")
local symbol_library =
    require("integrations.lsp.interaction.symbol-library")
local bindings =
    require("integrations.lsp.interaction.bindings")

return function(context)
    local interaction = {
        diagnostics = diagnostics(context),
        diagnostic_copy = diagnostic_copy(context),
        symbol_library = symbol_library(context),
    }

    bindings(context, interaction)
end
