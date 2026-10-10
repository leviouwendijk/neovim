-- Shared netrw entry resolution for cursor, marks, and visual selection.
-- Explicit visual selection takes priority over any pre-existing marks.
local uv = vim.uv or vim.loop
local M = {}

local function normalize(path)
    return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

-- Resolve aliases in parent directories, but never dereference the entry
-- itself: a symlink and its destination are different selectable entries.
local function entry_identity(path)
    if type(path) ~= "string" or path == "" then return nil end
    local absolute = normalize(path)
    local parent = vim.fs.dirname(absolute)
    local real_parent = parent and uv.fs_realpath(parent) or nil
    if not real_parent then return absolute end
    return vim.fs.normalize(vim.fs.joinpath(real_parent,
        vim.fs.basename(absolute)))
end

function M.same_entry(left, right)
    if not left or not right then return false end
    return entry_identity(left) == entry_identity(right)
end

local function same_directory(left, right)
    if not left or not right then return false end
    local a = normalize(left)
    local b = normalize(right)
    return (uv.fs_realpath(a) or a) == (uv.fs_realpath(b) or b)
end

function M.active_directory()
    local dir = vim.b.netrw_curdir
    if type(dir) == "string" and dir ~= "" then
        return normalize(dir)
    end
    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" and vim.fn.isdirectory(name) == 1 then
        return normalize(name)
    end
    return normalize(vim.fn.getcwd())
end

function M.marked_paths()
    local ok, list = pcall(vim.fn["netrw#Expose"], "netrwmarkfilelist")
    if not ok then return nil, tostring(list) end
    if type(list) ~= "table" then return {} end
    return list
end

function M.entry_at_row(row, win)
    win = win or vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(win) then return nil end
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= "netrw" then return nil end
    if row < 1 or row > vim.api.nvim_buf_line_count(buf) then return nil end
    local banner = vim.w[win].netrw_bannercnt
    if type(banner) == "number" and row < banner then return nil end

    local saved = vim.api.nvim_win_get_cursor(win)
    local col = row == saved[1] and saved[2] or 0
    if not pcall(vim.api.nvim_win_set_cursor, win, { row, col }) then
        return nil
    end
    local ok, name = pcall(vim.fn["netrw#Call"], "NetrwGetWord")
    pcall(vim.api.nvim_win_set_cursor, win, saved)
    if not ok or type(name) ~= "string" then return nil end
    name = name:gsub("/+$", "")
    if name == "" or name == "." or name == ".." then return nil end

    local dir = M.active_directory()
    local candidate = normalize(vim.fs.joinpath(dir, name))
    if candidate:sub(1, #dir + 1) ~= dir .. "/" then return nil end
    if not uv.fs_lstat(candidate) then return nil end
    return candidate
end

function M.resolve(opts)
    opts = opts or {}
    if vim.bo.filetype ~= "netrw" then
        return nil, nil, "Not a netrw buffer"
    end

    local paths, kind
    if opts.visual_rows then
        -- Wide netrw view can put multiple files on the same display row.
        if vim.w.netrw_liststyle == 2 then
            return nil, nil, "Switch to one-entry-per-line netrw view first"
        end
        kind, paths = "visual", {}
        local first = math.min(opts.visual_rows[1], opts.visual_rows[2])
        local last = math.max(opts.visual_rows[1], opts.visual_rows[2])
        for row = first, last do
            local candidate = M.entry_at_row(row)
            if candidate then paths[#paths + 1] = candidate end
        end
    else
        local marks, err = M.marked_paths()
        if not marks then return nil, nil, err end
        if #marks > 0 then
            kind, paths = "marks", marks
        else
            kind, paths = "cursor", {
                M.entry_at_row(vim.api.nvim_win_get_cursor(0)[1])
            }
        end
    end

    local result, seen = {}, {}
    for _, item in ipairs(paths) do
        if type(item) == "string" and item ~= "" then
            local absolute = normalize(item)
            if not uv.fs_lstat(absolute) then
                return nil, nil, "Selected entry no longer exists: " .. absolute
            end
            local identity = entry_identity(absolute) or absolute
            if not seen[identity] then
                result[#result + 1] = absolute
                seen[identity] = true
            end
        end
    end
    return result, kind
end

-- Keep the current entry if it survives. Otherwise choose the preceding
-- surviving entry, falling back to the next one at the beginning of a list.
function M.anchor(selected)
    local win = vim.api.nvim_get_current_win()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local marked = {}
    for _, item in ipairs(selected) do
        marked[entry_identity(item)] = true
    end
    local function survives(item)
        if not item then return false end
        local identity = entry_identity(item)
        if not identity then return false end
        if marked[identity] then return false end
        for _, source in ipairs(selected) do
            local full = entry_identity(source)
            local stat = uv.fs_lstat(source)
            if stat and stat.type == "directory"
                and identity:sub(1, #full + 1) == full .. "/" then
                return false
            end
        end
        return true
    end
    local current = M.entry_at_row(row, win)
    if survives(current) then return current end
    for index = row - 1, 1, -1 do
        local candidate = M.entry_at_row(index, win)
        if survives(candidate) then return candidate end
    end
    local last = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
    for index = row + 1, last do
        local candidate = M.entry_at_row(index, win)
        if survives(candidate) then return candidate end
    end
    return nil
end

function M.capture(selected)
    return {
        window = vim.api.nvim_get_current_win(),
        buffer = vim.api.nvim_get_current_buf(),
        directory = M.active_directory(),
        cursor = vim.api.nvim_win_get_cursor(0),
        anchor = M.anchor(selected),
    }
end

function M.refresh(ctx)
    if not ctx or not vim.api.nvim_win_is_valid(ctx.window) then return end
    if not uv.fs_stat(ctx.directory) then return end
    vim.api.nvim_win_call(ctx.window, function()
        -- Netrw can replace its backing buffer during a redraw. What must
        -- remain stable is the window's browsing directory, not its buffer ID.
        -- Never redirect a window that has moved to another directory/file.
        if vim.bo.filetype ~= "netrw"
            or not same_directory(M.active_directory(), ctx.directory) then
            return
        end
        vim.cmd("silent keepalt keepjumps edit " .. vim.fn.fnameescape(ctx.directory))
        if vim.bo.filetype ~= "netrw" then return end
        if ctx.anchor then
            for row = 1, vim.api.nvim_buf_line_count(0) do
                if M.same_entry(M.entry_at_row(row), ctx.anchor) then
                    vim.api.nvim_win_set_cursor(0, { row, 0 })
                    return
                end
            end
        end
        local row = math.max(1,
            math.min(ctx.cursor[1], vim.api.nvim_buf_line_count(0)))
        pcall(vim.api.nvim_win_set_cursor, 0, { row, 0 })
    end)
end

-- 'mu' unmarks only the current entry. This clears the completed marked set.
function M.clear_marks()
    return pcall(vim.fn["netrw#Call"], "NetrwUnmarkAll")
end

return M
