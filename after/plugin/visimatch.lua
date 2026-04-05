local funcs = require("config.funcs")

local visimatch = funcs.require_or_nil("visimatch", {
    message = "visimatch missing; skipping setup",
})

if not visimatch then
    return
end

visimatch.setup({
    -- The highlight group to apply to matched text
    hl_group = "Search",
    -- The minimum number of selected characters required to trigger highlighting
    chars_lower_limit = 6,
    -- The maximum number of selected lines to trigger highlighting for
    lines_upper_limit = 30,
    -- By default, visimatch will highlight text even if it doesn't have exactly
    -- the same spacing as the selected region. You can set this to `true` if
    -- you're not a fan of this behaviour :)
    strict_spacing = false,
    -- Visible buffers which should be highlighted. Valid options:
    -- * `"filetype"` (the default): highlight buffers with the same filetype
    -- * `"current"`: highlight matches in the current buffer only
    -- * `"all"`: highlight matches in all visible buffers
    buffers = "filetype",
    -- Case-(in)nsitivity for matches. Valid options:
    -- * `true`: matches will never be case-sensitive
    -- * `false`/`{}`: matches will always be case-sensitive
    -- * a table of filetypes to use use case-insensitive matching for.
    case_insensitive = { "markdown", "text", "help" },
})

-- Note: 
-- visimatch won't trigger in situations where the cursor doesn't move. 
-- In particular, this means that entering `viw` when the cursor is already at the end of the word won't trigger visimatch. 
-- In such situations, just move the cursor and highlights will trigger.
--

-- fix for deprecation warning
--
-- M.setup = function(opts)
--     config = vim.tbl_extend("force", config, opts or {})
--     vim.validate('hl_group', config.hl_group, 'string')
--     vim.validate('chars_lower_limit', config.chars_lower_limit, 'number')
--     vim.validate('lines_upper_limit', config.lines_upper_limit, 'number')
--     vim.validate('strict_spacing', config.strict_spacing, 'boolean')
--     vim.validate('buffers', config.buffers, function(x)
--         return type(x) == 'string' or type(x) == 'function'
--     end, 'string|function expected')
--     vim.validate('case_insensitive',  config.case_insensitive, function(x)
--         return type(x) == 'boolean' or type(x) == 'table'
--     end, 'boolean|table expected')
-- end
