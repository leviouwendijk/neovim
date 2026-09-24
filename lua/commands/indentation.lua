local funcs = require("config.funcs")

local indentation = funcs.require_or_nil("extensions.indentation", {
    message = "extensions.indentation missing; skipping indentation commands",
})

if not indentation then
    return
end

indentation.setup()

vim.api.nvim_create_user_command(
    "IndentNone",
    function()
        indentation.set("none")
    end, {}
)
vim.api.nvim_create_user_command(
    "IndentDotted",
    function()
        indentation.set("dotted")
    end, {}
)
vim.api.nvim_create_user_command(
    "IndentCountDots",
    function()
        indentation.set("countdots")
    end, {}
)
vim.api.nvim_create_user_command(
    "IndentCountDotsEnd",
    function()
        indentation.set("countdotsend")
    end, {}
)
vim.api.nvim_create_user_command(
    "IndentCountABC",
    function()
        indentation.set("countabc")
    end, {}
)

vim.schedule(
    function()
        indentation.set("countdotsend")
    end
)
