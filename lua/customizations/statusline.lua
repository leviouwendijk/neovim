-- Composes the global statusline by integrating:
--   - bedrocks-depth (already installed)
--   - extensions/word-count (logic only)
--
-- Modes:
--   mode = "path_left"   -- depth label shown left, before filename
--   mode = "right"       -- depth label shown on the right side block
--
-- Setup example:
--   require('customizations.statusline').setup({
--     mode = "right",
--     show_words = true,
--     bedrocks_root = os.getenv("HOME") .. "/myworkdir/ctxw",
--   })

local funcs = require("config.funcs")
local M = {}

local get_bd = funcs.once_require_or_nil("extensions.bedrocks-depth", {
    message = "extensions.bedrocks-depth missing; statusline Bedrocks section unavailable",
    silent = true,
})

local get_wc = funcs.once_require_or_nil("utils.word-count", {
    message = "utils.word-count missing; statusline word count unavailable",
    silent = true,
})

local cfg = {
    mode = "right",
    show_words = true,
    -- bedrocks_root = nil, -- if set, passed to bedrocks-depth.setup({root=...})
    bedrocks = {
        root = nil,
    },
}

local function bd_status()
    local bd = get_bd()
    if not bd then return "" end
    if cfg.bedrocks.root then
        pcall(bd.setup, { root = cfg.bedrocks.root })
    end
    local s = bd.status()
    return (s and #s > 0) and s or ""
end

-- Return "[filename]" only if:
--   • we're inside a Bedrocks tree, and
--   • current buffer is a normal file with a name.
function M.bedrocks_file_tag()
    local bd = get_bd()
    if not bd then return "" end

    -- Only show this when breadcrumbs are on the LEFT (path_left mode)
    if cfg.mode ~= "path_left" then return "" end

    -- Must be inside Bedrocks root
    local model = bd.current_model()
    if not model then return "" end

    -- Must be a normal named file buffer
    if vim.bo.buftype ~= "" then return "" end
    local name = vim.fn.expand("%:t")
    if name == "" then return "" end

    return "[" .. name .. "]"
end

function M.bedrocks_or_filename()
    local bd = get_bd()
    if not bd then
        return vim.fn.expand("%f")
    end
    if cfg.bedrocks.root then
        pcall(bd.setup, { root = cfg.bedrocks.root })
    end
    local model = bd.current_model()
    if model then
        -- inside Bedrocks tree → render your breadcrumb (no brackets)
        return bd.status()
    end
    -- outside Bedrocks → normal filename
    return vim.fn.expand("%f")
end

-- LEFT prefix when mode="path_left": we inject before %f
function M.left_prefix()
    if cfg.mode ~= "path_left" then return "" end
    return bd_status()
end

-- RIGHT chunk when mode="right": we print along the right side stats
function M.right()
    if cfg.mode ~= "right" then return "" end
    return bd_status()
end

-- Words (shared helper)
local function words_component()
    if not cfg.show_words then return "" end
    local wc = get_wc()
    if not wc then return "" end
    return wc.count_str() .. " words"
end

-- RIGHT tail common (after %l:%c | %p%% | %L lines)
function M.right_tail()
    local parts = {}

    -- When mode=right, bedrocks label lives on the right
    local right = M.right()
    if right ~= "" then table.insert(parts, right) end

    local tag = M.bedrocks_file_tag()
    if tag ~= "" then table.insert(parts, tag) end

    -- words
    local w = words_component()
    if w ~= "" then table.insert(parts, w) end

    if #parts == 0 then return "" end
    return " | " .. table.concat(parts, " | ")
end

-- Build and set the global statusline
function M.setup(opts)
    opts = opts or {}
    if opts.mode then cfg.mode = opts.mode end
    if opts.show_words ~= nil then cfg.show_words = opts.show_words end
    if opts.bedrocks_root then
        cfg.bedrocks.root = opts.bedrocks_root
    end

    if opts.bedrocks and opts.bedrocks.root then
        cfg.bedrocks.root = opts.bedrocks.root
    end

    -- Left side:
    --   path_left →  bedrocks_or_filename() %m %r %h
    --   right     →  %f %m %r %h
    local left
    if cfg.mode == "path_left" then
        left = table.concat({
            "%{%v:lua.require('customizations.statusline').bedrocks_or_filename()%}",
            "%m", "%r", "%h"
        }, " ")
    else
        left = "%f %m %r %h"
    end

    -- Right side:
    local right = table.concat({
        "%=",
        "%l:%c", "| %p%%", "%<", "%L lines",
        "%{%v:lua.require('customizations.statusline').right_tail()%}",
    }, " ")

    vim.o.statusline = left .. " " .. right
end

return M
