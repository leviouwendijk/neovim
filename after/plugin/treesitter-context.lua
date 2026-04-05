local funcs = require("config.funcs")

local context = funcs.require_or_nil("treesitter-context", {
    message = "treesitter-context missing; skipping setup",
})

if not context then
    return
end

local down_arrowhead = "⌄"
-- local bottom_parentheses = "⏝"

context.setup{
    enable = true,
    max_lines = 3,
    -- trim_scope = "outer",
    trim_scope = "inner",

    -- show context determined by cursor position (cursor) or top visible line (topline)
    -- mode = "cursor",
    mode = "topline",

    -- separator = nil,
    -- separator = "-",
    separator = down_arrowhead,
    zindex = 20,

    min_window_height = 0,
}
-- vim.keymap.set("n", "<leader>tc", function()
--     pcall(require("treesitter-context").toggle)
-- end, {
--         desc = "Toggle Treesitter Context",
--         silent = true
--     }
-- )
