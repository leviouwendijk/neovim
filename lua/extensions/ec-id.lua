local uv = vim.loop
local acc = require("accessor")
local funcs = require("config.funcs")

local M = {}

-- defaults
local cfg = {
    cmd = vim.deepcopy(acc.bin.ec.id.next),
    kind = "entry",          -- "entry" | "transaction"
    hops = 4,                -- walk up this many parents to find entries/
    use_stdout_flag = true,  -- pass --stdout to CLI
    notify_collisions = true,
    insert_target = "buffer",-- "buffer" | "register" | "clipboard" | "echo"
    register = '"',          -- unnamed register for fallback
}

function M.setup(opts)
    if type(opts) == "table" then
        for k, v in pairs(opts) do cfg[k] = v end
    end
end

-- Insert text at cursor (no newline)
local function insert_at_cursor(text)
    local bt = vim.bo.buftype
    if bt ~= "" or not vim.bo.modifiable then
        -- fallback: can't edit this buffer
        vim.fn.setreg(cfg.register, text)
        vim.notify(("next id → put in register %s: %s"):format(cfg.register, text))
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { text })
    vim.api.nvim_win_set_cursor(0, { row, col + #text })
end

-- Walk up to `cfg.hops` parents to find a dir containing 'entries/'
local function find_project_root(start)
    local path = start
    for _ = 0, cfg.hops do
        local stat = uv.fs_stat(path .. "/entries")
        if stat and stat.type == "directory" then
            return path
        end
        local parent = vim.fn.fnamemodify(path, ":h")
        if parent == path then break end
        path = parent
    end
    return nil
end

local function parse_first_number(lines)
    if not lines then return nil end
    for _, line in ipairs(lines) do
        if line and line:match("%S") then
            local n = tonumber((line:gsub("%s+", "")))
            if n then return n end
        end
    end
    return nil
end

function M.next(kind)
    kind = kind or cfg.kind
    local cwd = vim.fn.getcwd()
    local root = find_project_root(cwd) or cwd

    local cmd = vim.deepcopy(cfg.cmd)
    if cfg.use_stdout_flag then table.insert(cmd, "--stdout") end
    table.insert(cmd, "--kind");    table.insert(cmd, kind)
    table.insert(cmd, "--project"); table.insert(cmd, root)

    local job = funcs.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,

        on_stdout = function(_, data)
            local num = parse_first_number(data)
            if num then
                local s = tostring(num)
                if cfg.insert_target == "buffer" then
                    insert_at_cursor(s)
                elseif cfg.insert_target == "register" then
                    vim.fn.setreg(cfg.register, s)
                    vim.notify(("next id → register %s: %s"):format(cfg.register, s))
                elseif cfg.insert_target == "clipboard" then
                    vim.fn.setreg("+", s)
                    vim.notify("next id → clipboard: " .. s)
                else
                    vim.api.nvim_echo({ { s, "None" } }, false, {})
                end
            else
                vim.notify("ec: could not parse next id from stdout", vim.log.levels.ERROR)
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
            if code ~= 0 then
                vim.notify("ec id next failed (exit " .. tostring(code) .. ")", vim.log.levels.ERROR)
            end
        end,
    })

    if job <= 0 then
        return
    end
end

return M
