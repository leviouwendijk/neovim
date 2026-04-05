local funcs = require("config.funcs")

vim.api.nvim_create_user_command(
    "CheckDeps",
    function()
        local deps = funcs.require_or_nil("utils.dependencies", {
            message = "utils.dependencies missing; CheckDeps unavailable",
        })

        if not deps then
            return
        end

        deps.run()
    end, {
        desc = "Check external dependencies for this config",
    }
)
