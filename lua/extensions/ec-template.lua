local uv = vim.loop
local acc = require("accessor")
local funcs = require("config.funcs")

local M = {}

-- config
local cfg = {
    cmd = vim.deepcopy(acc.bin.ec.id.next),
    kind = "entry",               -- default kind
    hops = 4,                     -- walk up to find entries/
    use_stdout_flag = true,
    notify_collisions = true,
}

function M.setup(opts)
    if type(opts) == "table" then
        for k, v in pairs(opts) do cfg[k] = v end
    end
end

-- ----- utils -----
local function find_project_root(start)
    local path = start
    for _ = 0, cfg.hops do
        local st = uv.fs_stat(path .. "/entries")
        if st and st.type == "directory" then return path end
        local parent = vim.fn.fnamemodify(path, ":h")
        if parent == path then break end
        path = parent
    end
    return nil
end

local function fetch_next_id(kind, on_ok, on_err)
    kind = kind or cfg.kind
    local cwd  = vim.fn.getcwd()
    local root = find_project_root(cwd) or cwd

    local cmd = vim.deepcopy(cfg.cmd)
    if cfg.use_stdout_flag then table.insert(cmd, "--stdout") end
    table.insert(cmd, "--kind");    table.insert(cmd, kind)
    table.insert(cmd, "--project"); table.insert(cmd, root)

    local job = funcs.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,

        on_stdout = function(_, data)
            if not data then return end
            local num
            for _, line in ipairs(data) do
                if line and line:match("%S") then
                    num = tonumber((line:gsub("%s+", "")))
                    if num then break end
                end
            end
            if num then
                on_ok(num)
            else
                if on_err then on_err("could not parse next id from stdout") end
            end
        end,

        on_stderr = function(_, data)
            if cfg.notify_collisions and data and #data > 0 then
                local msg = table.concat(data, "\n")
                if msg:match("%S") then
                    vim.notify(msg, vim.log.levels.WARN)
                end
            end
        end,

        on_exit = function(_, code)
            if code ~= 0 and on_err then
                on_err("ec id next failed (exit " .. tostring(code) .. ")")
            end
        end,
    })

    if job <= 0 then
        if on_err then
            on_err("failed to start ec id job")
        end
        return
    end

    -- vim.fn.jobstart(cmd, {
    --     stdout_buffered = true,
    --     stderr_buffered = true,

    --     on_stdout = function(_, data)
    --         if not data then return end
    --         local num
    --         for _, line in ipairs(data) do
    --             if line and line:match("%S") then
    --                 num = tonumber((line:gsub("%s+", "")))
    --                 if num then break end
    --             end
    --         end
    --         if num then
    --             on_ok(num)
    --         else
    --             if on_err then on_err("could not parse next id from stdout") end
    --         end
    --     end,

    --     on_stderr = function(_, data)
    --         if cfg.notify_collisions and data and #data > 0 then
    --             local msg = table.concat(data, "\n")
    --             if msg:match("%S") then vim.notify(msg, vim.log.levels.WARN) end
    --         end
    --     end,

    --     on_exit = function(_, code)
    --         if code ~= 0 and on_err then on_err("ec id next failed (exit " .. tostring(code) .. ")") end
    --     end,
    -- })
end

local function insert_lines(lines)
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.bo.buftype ~= "" or not vim.bo.modifiable then
        local text = table.concat(lines, "\n")
        vim.fn.setreg('"', text)
        vim.notify("template copied to default register", vim.log.levels.INFO)
        return
    end
    local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-based
    vim.api.nvim_buf_set_lines(bufnr, row, row, false, lines)
    -- place cursor on first underscore placeholder if present
    for i, l in ipairs(lines) do
        local s = l:find("_", 1, true)
        if s then
            vim.api.nvim_win_set_cursor(0, { row + i, s - 1 }) -- col 0-based
            break
        end
    end
end

-- indentation helpers
local function leading_ws(s) return (s:match("^%s*") or "") end
local function indent_unit()
    local sw = vim.bo.shiftwidth
    if sw == 0 then sw = vim.o.shiftwidth end
    if sw == 0 then sw = 4 end
    return string.rep(" ", sw)
end

-- ----- templates -----

-- mirrored entry (regular)
function M.insert_mirrored(kind)
    fetch_next_id(kind, function(id)
        local curline = vim.api.nvim_get_current_line()
        local base    = leading_ws(curline)
        local one     = base .. indent_unit()
        local two     = one .. indent_unit()

        local lines = {
            base .. "entry {",
            one  .. ("id = %d "):format(id),
            base .. "",
            one  .. "date infer _",
            base .. "",
            one  .. "sort regular",
            base .. "",
            one  .. "details {",
            two  .. "_",
            one  .. "}",
            base .. "",
            one  .. "for (_) in (_) {",
            two  .. "_ = _",
            one  .. "}",
            base .. "",
            one  .. "for (_) in (_) {",
            two  .. "_ = _",
            one  .. "}",
            base .. "}",
        }

        insert_lines(lines)
    end, function(err)
    vim.notify("template: " .. err, vim.log.levels.ERROR)
    -- fallback: insert with id placeholder
    local curline = vim.api.nvim_get_current_line()
    local base    = leading_ws(curline)
    local one     = base .. indent_unit()
    local two     = one .. indent_unit()
    insert_lines({
        base .. "entry {",
        one  .. "id = _",
        base .. "",
        one  .. "date infer _",
        base .. "",
        one  .. "sort regular",
        base .. "",
        one  .. "details {",
        two  .. "_",
        one  .. "}",
        base .. "",
        one  .. "for (_) in (_) {",
        two  .. "_ = _",
        one  .. "}",
        base .. "",
        one  .. "for (_) in (_) {",
        two  .. "_ = _",
        one  .. "}",
        base .. "}",
    })
end)
end

-- registry for future templates
M.templates = {
    mirrored = M.insert_mirrored,
}

function M.insert(name, kind)
    local f = M.templates[name]
    if not f then
        vim.notify("unknown template: " .. tostring(name), vim.log.levels.ERROR)
        return
    end
    f(kind)
end

return M
