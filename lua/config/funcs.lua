local M = {}

local acc = require("accessor")
local warned = {}

function M.safe_notify(msg, level, opts)
    level = level or vim.log.levels.INFO
    opts = opts or {}

    if vim.notify then
        pcall(vim.notify, msg, level, opts)
        return
    end

    vim.schedule(function()
        pcall(vim.api.nvim_echo, { { tostring(msg), "" } }, true, {})
    end)
end

function M.warn_once(key, msg, level, opts)
    if warned[key] then
        return
    end

    warned[key] = true
    M.safe_notify(msg, level or vim.log.levels.WARN, opts)
end

function M.head(spec)
    if type(spec) == "string" then
        return spec
    end

    if type(spec) == "table" then
        if spec.bin ~= nil then
            return M.head(spec.bin)
        end

        if spec.production ~= nil then
            return M.head(spec.production)
        end

        return M.head(spec[1])
    end

    if type(spec) == "function" then
        local ok, value = pcall(spec)
        if ok then
            return M.head(value)
        end
    end

    return nil
end

function M.has_executable(spec)
    local cmd = M.head(spec)

    if type(cmd) ~= "string" or cmd == "" then
        return false, nil
    end

    return vim.fn.executable(cmd) == 1, cmd
end

function M.require_or_nil(name, opts)
    local ok, mod = pcall(require, name)
    if ok then
        return mod
    end

    opts = opts or {}

    if not opts.silent then
        M.warn_once(
            "require:" .. name,
            opts.message or ("Missing module: " .. name),
            vim.log.levels.WARN
        )
    end

    return nil
end

function M.jobstart(cmd, opts)
    local ok, head = M.has_executable(cmd)

    if not ok then
        M.warn_once(
            "bin:" .. tostring(head),
            ("Missing executable: %s"):format(tostring(head or "?")),
            vim.log.levels.WARN
        )
        return -1
    end

    local job = vim.fn.jobstart(cmd, opts or {})
    if job <= 0 then
        M.safe_notify(
            ("Failed to start job: %s"):format(head),
            vim.log.levels.ERROR
        )
    end

    return job
end

function M.system(cmd, input)
    local ok, head = M.has_executable(cmd)

    if not ok then
        M.warn_once(
            "bin:" .. tostring(head),
            ("Missing executable: %s"):format(tostring(head or "?")),
            vim.log.levels.WARN
        )
        return nil, false
    end

    local out
    if input ~= nil then
        out = vim.fn.system(cmd, input)
    else
        out = vim.fn.system(cmd)
    end

    return out, vim.v.shell_error == 0
end

function M.open_path(path, fail_message)
    if not path or path == "" then
        M.safe_notify(fail_message or "No path to open", vim.log.levels.ERROR)
        return
    end

    local job = M.jobstart({ acc.bin.open, path }, {
        on_exit = function(_, code)
            vim.schedule(function()
                if code == 0 then
                    M.safe_notify("Opened: " .. path)
                else
                    M.safe_notify(
                        fail_message or "Failed to open path",
                        vim.log.levels.ERROR
                    )
                end
            end)
        end,
    })

    if job <= 0 then
        M.safe_notify("Open helper is unavailable", vim.log.levels.WARN)
    end
end

function M.open_current_file()
    M.open_path(vim.fn.expand("%:p"), "Failed to open file")
end

function M.open_cwd()
    M.open_path(vim.fn.getcwd(), "Failed to open directory")
end

function M.open_current_path()
    M.open_path(vim.fn.expand("%:p"), "Failed to open path")
end

function M.select_whole_buffer()
    vim.api.nvim_feedkeys("GVgg", "n", true)
end

function M.insert_swift_dirs()
    local cwd = vim.fn.expand("%:p")
    vim.fn.mkdir(cwd .. "funcs")
    vim.fn.mkdir(cwd .. "network")
    vim.fn.mkdir(cwd .. "extensions")
    vim.fn.mkdir(cwd .. "viewmodels")
    vim.fn.mkdir(cwd .. "models")
    vim.fn.mkdir(cwd .. "views")
    vim.cmd("e")
end

function M.copy_filepath_to_clipboard()
    local file_path = vim.fn.expand("%:p")
    local _, ok = M.system({ acc.bin.pbcopy }, file_path)

    if ok then
        M.safe_notify("Copied file path: " .. file_path)
    else
        M.safe_notify("Failed to copy file path", vim.log.levels.ERROR)
    end
end

function M.once_require(name)
    local mod

    return function()
        if mod == nil then
            mod = require(name)
        end

        return mod
    end
end

function M.once_require_or_nil(name, opts)
    local mod
    local tried = false

    return function()
        if mod ~= nil then
            return mod
        end

        if tried then
            return nil
        end

        tried = true
        mod = M.require_or_nil(name, opts)
        return mod
    end
end

function M.current_file()
    return vim.fn.expand("%:p")
end

return M
