local M = {}

local function is_macos()
    return vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1
end

---Returns "dark" or "light" (nil if not macOS)
function M.get_macos_appearance()
    if not is_macos() then return nil end
    local out = vim.fn.systemlist({ "defaults", "read", "-g", "AppleInterfaceStyle" })
    if vim.v.shell_error == 0 and #out > 0 and out[1]:lower() == "dark" then
        return "dark"
    end
    return "light" -- key is absent in light mode
end

---Returns true/false for “Auto” toggle (nil if not macOS)
function M.is_auto_enabled()
    if not is_macos() then return nil end
    -- Exists (exit 0) when Auto is on; missing/err when off
    vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyleSwitchesAutomatically" })
    return vim.v.shell_error == 0
end

local acc = require("accessor")
local funcs = require("config.funcs")

local observer_job = nil
local observer_stopping = false

local function publish(mode)
    if mode ~= "dark" and mode ~= "light" then
        return
    end

    vim.schedule(function()
        if observer_stopping then
            return
        end

        vim.api.nvim_exec_autocmds("User", {
            pattern = "SystemAppearanceChanged",
            data = { mode = mode },
        })
    end)
end

function M.watch_macos_appearance()
    if not is_macos() then
        return false
    end

    if observer_job then
        return true
    end

    observer_stopping = false
    local partial = ""
    local command = { funcs.head(acc.bin.sysappear), "watch" }

    local job = funcs.jobstart(command, {
        stdout_buffered = false,
        on_stdout = function(_, chunks)
            if not chunks or #chunks == 0 then
                return
            end

            chunks[1] = partial .. chunks[1]
            partial = table.remove(chunks) or ""

            for _, mode in ipairs(chunks) do
                publish(mode)
            end
        end,
        on_exit = function(job_id, code)
            vim.schedule(function()
                if observer_job == job_id then
                    observer_job = nil
                end

                if not observer_stopping then
                    funcs.safe_notify(
                        ("sysappear watcher exited (code %d)"):format(code),
                        vim.log.levels.WARN
                    )
                end
            end)
        end,
    })

    if job <= 0 then
        return false
    end

    observer_job = job
    return true
end

function M.stop_macos_appearance()
    observer_stopping = true

    if observer_job then
        vim.fn.jobstop(observer_job)
        observer_job = nil
    end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("SystemAppearanceWatch", { clear = true }),
    callback = M.stop_macos_appearance,
})
return M
