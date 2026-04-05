local funcs = require("config.funcs")
local acc = require("accessor")
funcs.require_or_nil("utils.word-count", {
    message = "utils.word-count missing; continuing without eager preload",
    silent = true,
})
local bedrocks_depth = funcs.require_or_nil("extensions.bedrocks-depth", {
    message = "extensions.bedrocks-depth missing; skipping statusline setup",
})
local statusline = funcs.require_or_nil("customizations.statusline", {
    message = "customizations.statusline missing; skipping statusline setup",
})
if not bedrocks_depth or not statusline then
    return
end
local bedrocks_root = acc.paths.bedrocks.root

local function set_statusline_variants()
    local ok, base = pcall(vim.api.nvim_get_hl, 0, { name = "StatusLine", link = false })
    if not ok or not base then return end
    local bold, italic = { bold = true }, { italic = true }
    if base.fg then bold.fg, italic.fg = base.fg, base.fg end
    if base.bg then bold.bg, italic.bg = base.bg, base.bg end
    if base.sp then bold.sp, italic.sp = base.sp, base.sp end
    vim.api.nvim_set_hl(0, "StatusLineBold", bold)
    vim.api.nvim_set_hl(0, "StatusLineItalic", italic)
end
vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, { callback = set_statusline_variants })
_G._StatusLineVariants_refresh = set_statusline_variants

-- Returns Bedrocks breadcrumb (no brackets) if inside the root; else filename.
function _G.Bedrocks_or_filename()
    local ok, bd = pcall(require, "extensions.bedrocks-depth")
    if not ok then
        return vim.fn.expand("%f")
    end
    local m = bd.current_model()
    if m then
        -- Use your configured formatter output. No extra [] here.
        return bd.status()
    else
        return vim.fn.expand("%f")
    end
end

local BOLD, ITAL, RST = "%#StatusLineBold#", "%#StatusLineItalic#", "%*"
local SEP = " › "
local tag = { domain=" (d)", project=" (p)", scope=" (s)", conversation=" (c)", thread=" (t)" }

local function crumb_upto(m, upto)
    local order = { "domain", "project", "scope", "conversation" }
    local segs = {}
    for _, lv in ipairs(order) do
        local name = m.refs[lv]
        if name then
            if lv == "conversation" then
                -- Bold only conversation segment
                table.insert(segs, BOLD .. name .. tag[lv] .. RST)
            else
                table.insert(segs, name .. tag[lv])
            end
        end
        if lv == upto then break end
    end
    return table.concat(segs, SEP)
end

bedrocks_depth.setup(
    {
        -- root = os.getenv("HOME") .. "/myworkdir/ctxw",
        root = bedrocks_root,
        -- optional legacy annotations (kept working)
        -- show_refs = { conversation = { "domain" } },
        formatters = {
            -- Root: either empty or show a small tag. Pick one line and keep the other commented.
            root = function(m)
                -- return ""  -- (do nothing at root)
                local root_name = vim.fn.fnamemodify(m.root, ":t")
                return "@bedrocks: " .. root_name
            end,

            domain = function(m)
                local d = m.refs.domain or vim.fn.fnamemodify(m.cwd, ":t")
                return d .. tag.domain
            end,

            project = function(m)
                return crumb_upto(m, "project")
            end,

            scope = function(m)
                return crumb_upto(m, "scope")
            end,

            conversation = function(m)
                local line = crumb_upto(m, "conversation")
                -- If we're exactly in the conversation/threads/ container, append a hint
                if m._trailing_threads then
                    line = line .. SEP .. "threads"
                end
                return line
            end,

            thread = function(m)
                -- Breadcrumb up to conversation (conversation already bold),
                -- then add italic thread name with (t)
                local bc = crumb_upto(m, "conversation")
                local thr = m.refs.thread or vim.fn.fnamemodify(m.cwd, ":t")
                return bc .. SEP .. ITAL .. thr .. tag.thread .. RST
            end,
        },
    }
)

statusline.setup(
    {
        mode = "path_left",  -- "right" or "path_left"
        show_words = true,
        bedrocks_root = bedrocks_root,
    }
)

-- Netrw-specific refreshes: attach only after a netrw buffer exists (no early netrw init)
vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function(ev)
        -- buffer-local light refresh hooks (safe; netrw reuses buffers)
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorMoved" }, {
            buffer = ev.buf,
            callback = function() vim.cmd("redrawstatus") end,
        })
    end,
})
