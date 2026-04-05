local M = {}

local acc = require("accessor")
local bedrocks_root = acc.paths.bedrocks.root
local home = acc.paths.home

-- Default root of your Bedrocks partitions.
-- Change via setup({ root = "…" }) if you ever move it.
-- local HOME = os.getenv("HOME") or ""
-- local DEFAULT_ROOT = HOME .. "/myworkdir/ctxw"

-- Depth → label mapping (plural “next collection” or singular when desired)
-- 0: ctxw root             → "domains"
-- 1: in a domain           → "projects"
-- 2: in a project          → "scopes"
-- 3: in a scope            → "conversations"
-- 4: in a conversation dir → "conversation" (singular)
-- 5: in .../threads[/...]  → "threads" (only if last segment IS 'threads'; otherwise 'thread')
local DEFAULT_LABEL_BY_DEPTH = {
    [0] = "domains",
    [1] = "projects",
    [2] = "scopes",
    [3] = "conversations",
    [4] = "conversation",
    [5] = "threads", -- only when last segment is literally "threads"
}

local DEFAULT_EXCLUSIONS = { "context", "data" }

local AT_LEVEL_NAME = { "domain", "project", "scope", "conversation", "thread" }

local state = {
    -- root = DEFAULT_ROOT,
    root = bedrocks_root,
    show_refs = {},
    formatters = {},
}

---Normalize path (expand ~, realpath when possible), no trailing slash.
local function norm(p)
    if not p or p == "" then return "" end
    p = p:gsub("^~", home)
    -- fs_realpath returns nil if it doesn't exist; fall back to cleaned input
    local rp = (vim.loop and vim.loop.fs_realpath and vim.loop.fs_realpath(p)) or p
    -- remove trailing slash (except for "/")
    rp = rp:gsub("/+$", "")
    if rp == "" then return p end
    return rp
end

---Split path into components
local function split(path)
    local t = {}
    for part in string.gmatch(path, "[^/]+") do
        table.insert(t, part)
    end
    return t
end

function M.model(path)
    local root = norm(state.root)

    -- Normalize the incoming path and ensure we operate on a DIRECTORY.
    local here = norm(path or vim.fn.getcwd())

    -- If caller gave us a FILE path, switch to its parent directory.
    do
        local st = vim.loop.fs_stat(here)
        if st and st.type == "file" then
            here = norm(vim.fn.fnamemodify(here, ":h"))
        end
    end

    -- Outside the root? disable
    if here:sub(1, #root) ~= root then return nil end

    local rel = here:sub(#root + 1):gsub("^/", "")
    local raw_parts = (rel == "" and {} or split(rel))

    -- 1) Trailing exclusions (e.g., "context") do NOT advance depth
    local parts = {}
    for i = 1, #raw_parts do parts[i] = raw_parts[i] end
    local trailing_context = false
    if #parts > 0 then
        for _, ex in ipairs(DEFAULT_EXCLUSIONS) do
            if parts[#parts] == ex then
                trailing_context = true
                table.remove(parts)
                break
            end
        end
    end

    -- 2) A trailing "threads" segment is counted as its own depth (index 5)
    local trailing_threads = (parts[#parts] == "threads")
    local depth = #parts

    -- Labels
    local next_label = DEFAULT_LABEL_BY_DEPTH[depth] or "thread"
    if depth == 5 and not trailing_threads then
        -- We're inside threads/<name> which is a real thread
        next_label = "thread"
    end

    -- Semantic level (threads container is still “conversation” level)
    local at_level = AT_LEVEL_NAME[depth] or "thread"
    if trailing_threads then at_level = "conversation" end

    -- Refs map (domain/project/scope/conversation[/thread])
    local refs = {}
    for i = 1, math.min(depth, #AT_LEVEL_NAME) do
        refs[AT_LEVEL_NAME[i]] = parts[i]
    end
    if trailing_threads then
        refs.thread = nil
    end

    -- If we're inside "threads/<name>", use <name> as the thread ref (not the "threads" container)
    if parts[5] == "threads" and parts[6] then
        refs.thread = parts[6]
    end

    -- Ancestors (root→current), each { level, name, path }
    local ancestors, _acc = {}, root
    for i = 1, depth do
        local lvl = AT_LEVEL_NAME[i] or "thread"
        local name = parts[i]
        _acc = _acc .. "/" .. name
        table.insert(ancestors, { level = lvl, name = name, path = _acc })
    end

    return {
        root = root,
        cwd = here,
        rel = rel,
        raw_parts = raw_parts,
        parts = parts,
        depth = depth,
        at_level = at_level,
        next_label = next_label,
        refs = refs,
        ancestors = ancestors,
        _trailing_context = trailing_context,
        _trailing_threads = trailing_threads,
    }
end

-- function M.depth_of(path)
--     return M.model(path)
-- end

function M.current_model()
    -- netrw: prefer b:netrw_curdir
    if vim.bo.filetype == "netrw" then
        local nd = vim.b.netrw_curdir
        if nd and #nd > 0 then
            return M.model(nd)
        end
    end

    -- For normal file buffers, prefer the *buffer's directory*.
    -- This avoids counting the filename and avoids surprises from window-local cwd.
    if vim.bo.buftype == "" then
        local full = vim.fn.expand("%:p")  -- may be empty for [No Name]
        if full ~= "" then
            return M.model(vim.fn.fnamemodify(full, ":h"))
        end
    end

    -- Otherwise: window-local CWD, then global CWD
    local win_cwd = vim.fn.getcwd(0, 0)
    local base = (win_cwd and #win_cwd > 0) and win_cwd or vim.fn.getcwd()
    return M.model(base)
end

-- -- Replace your existing current() with this (keeps old API name)
-- function M.current()
--     return M.current_model()
-- end

-- (lets you fully control formatting per-level)
function M.register_formatter(level, fn)
    state.formatters[level] = fn
end

function M.status()
    local info = M.current_model()
    if not info then return "" end

    -- Prefer per-level formatter; allow a dedicated "root" formatter when depth==0
    local key = (info.depth == 0) and "root" or info.at_level
    local fmt = state.formatters[key]
    if type(fmt) == "function" then
        local ok, out = pcall(fmt, info)
        if ok and type(out) == "string" then return out end
    end

    -- Fallback: old default (kept for safety, but you won't hit it with your formatters)
    local label = info.next_label
    if info.depth >= 1 and info.depth <= #AT_LEVEL_NAME and label ~= "thread" then
        local name
        if info._trailing_context or info._trailing_threads then
            name = vim.fn.fnamemodify(info.cwd, ":h:t")
        else
            name = vim.fn.fnamemodify(info.cwd, ":t")
        end
        label = string.format("%s (%s=%s)", label, info.at_level, name)
    end
    return label
end

---Allow overriding the root.
---Usage: require('extensions.bedrocks-depth').setup{ root = "/other/root" }
function M.setup(opts)
    if not opts then return end
    if opts.root then
        state.root = norm(opts.root)
    end
    if opts.formatters then
        -- { [level] = function(model) return "<statusline>" end }
        state.formatters = vim.deepcopy(opts.formatters)
    end
    if opts.show_refs then
        -- Optional legacy fallback annotation control: { [level] = { "domain", "scope", ... } }
        state.show_refs = vim.deepcopy(opts.show_refs)
    end
end

return M
