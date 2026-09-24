return function(context)
    local bedrocks_root = context.root
    local bedrocks_depth = context.depth

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
end
