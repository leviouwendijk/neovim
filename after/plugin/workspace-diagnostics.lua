local funcs = require("config.funcs")

local function set_workspace_for_lsp()
    local wd = funcs.require_or_nil("workspace-diagnostics", {
        message = "workspace-diagnostics missing; SetLSP unavailable",
    })

    if not wd then
        return
    end

    for _, client in ipairs(vim.lsp.get_clients()) do
        wd.populate_workspace_diagnostics(client, 0)
    end
end

vim.api.nvim_create_user_command(
    "SetLSP",
    set_workspace_for_lsp,
    { nargs = 0 }
)
