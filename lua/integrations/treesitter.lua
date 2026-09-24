require("integrations.treesitter.context")

local funcs = require("config.funcs")

local ts = funcs.require_or_nil("nvim-treesitter", {
    message = "nvim-treesitter missing; skipping setup",
})
local ts_boot = funcs.require_or_nil("core.treesitter", {
    message = "core.treesitter missing; skipping custom parser setup",
})

if not ts or not ts_boot then
    return
end

local ts_group = vim.api.nvim_create_augroup("LeviTreesitter", { clear = true })

ts.setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
})

local context = {
    funcs = funcs,
    ts = ts,
    ts_boot = ts_boot,
    group = ts_group,
}

require("integrations.treesitter.parsers")(context)
require("integrations.treesitter.buffers")(context)
