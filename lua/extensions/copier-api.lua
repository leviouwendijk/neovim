Copier = {}
-- BEFORE
-- local notify = require("notify")

-- AFTER (custom pcall)
local notify = require("utils.notify")   -- exposes .info/.warn/.error/.debug
local acc = require("accessor")
local funcs = require("config.funcs")

-- Master settings
Copier.master_copier_enable = true
Copier.auto_push_enabled = true
Copier.auto_fetch_enabled = true
Copier.silence_output = true

Copier.clipboard_file = acc.paths.clipboard_file

local function debug(message)
    if not Copier.silence_output then
        -- print(message)
        notify.debug(message)
    end
end

-- local function execute_command(command)
--     local handle = io.popen(command)

--     if not handle then
--         notify.error("Failed to execute command: " .. command)
--         return nil, "Execution failed"
--     end

--     local result = handle:read("*a")
--     handle:close()

--     return result, nil
-- end

local function execute_command(command)
    local result, ok = funcs.system(command)

    if not ok then
        notify.error("Failed to execute command: " .. table.concat(command, " "))
        return nil, "Execution failed"
    end

    return result, nil
end

function Copier.push_clipboard()
    if not Copier.master_copier_enable then
        debug("Copier (master boolean) is not enabled.")
        return
    end

    if not Copier.auto_push_enabled then
        debug("Auto-push is disabled.")
        return
    end

    local clipboard_content = vim.fn.getreg('"')
    if clipboard_content == "" then
        debug("Clipboard is empty. Nothing to sync.")
        return
    end

    local file = io.open(Copier.clipboard_file, "w")
    if not file then
        notify.error("Error: Could not open clipboard file for writing.")
        vim.cmd("redraw")
        return
    end

    file:write(clipboard_content)
    file:close()

    local command = { acc.bin.copier, "push" }
    local output, push_err = execute_command(command)

    if push_err then
        notify.error("Clipboard push failed: " .. push_err)
        vim.cmd("redraw")
        return
    end

    notify.info("/clipboard/provide")
    if not Copier.silence_output and output and output ~= "" then
        notify.info(output)
    end

    vim.cmd("redraw") -- Ensure UI updates properly
end

function Copier.fetch_clipboard()
    if not Copier.master_copier_enable then
        notify.warn("Copier (master boolean) is not enabled.")
        return
    end

    if not Copier.auto_fetch_enabled then
        notify.warn("Auto-fetch is disabled.")
        return
    end

    local command = { acc.bin.copier, "fetch" }
    local _, fetch_err = execute_command(command)

    if fetch_err then
        notify.error("Clipboard fetch failed: " .. fetch_err)
        vim.cmd("redraw")
        return
    end

    local file = io.open(Copier.clipboard_file, "r")
    if not file then
        notify.error("Error: Could not open clipboard file for reading.")
        vim.cmd("redraw")
        return
    end

    local clipboard_content = file:read("*a")
    file:close()

    vim.schedule(function()
        local success, setreg_err = pcall(vim.fn.setreg, "+", clipboard_content)
        if success then
            notify.info("Clipboard content updated successfully!")
        else
            notify.error("Failed to update clipboard register: " .. setreg_err)
        end
        vim.cmd("redraw") -- Prevent display corruption
    end)
end

-- Toggle auto-push
function Copier.toggle_auto_push()
    Copier.auto_push_enabled = not Copier.auto_push_enabled
    notify.info("Auto-push is now " .. (Copier.auto_push_enabled and "enabled" or "disabled"))
end

-- Toggle auto-fetch
function Copier.toggle_auto_fetch()
    Copier.auto_fetch_enabled = not Copier.auto_fetch_enabled
    notify.info("Auto-fetch is now " .. (Copier.auto_fetch_enabled and "enabled" or "disabled"))
end

-- Autocommand for automatic clipboard sync
-- Potential culprit of clipboard register pollution?
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        -- adding guard:
        if vim.v.event.operator ~= "y" then
            return
        end

        pcall(function()
            Copier.push_clipboard()
        end)
    end,
})

-- User Commands
vim.api.nvim_create_user_command("CopierProvide", Copier.toggle_auto_push, {})
vim.api.nvim_create_user_command("CopierAcquire", Copier.toggle_auto_fetch, {})
vim.api.nvim_create_user_command("CopierAll", function()
    Copier.toggle_auto_push()
    Copier.toggle_auto_fetch()
end, {})

-- Key mappings
vim.api.nvim_set_keymap("n", "<leader>pp", ":lua Copier.push_clipboard()<CR>", { noremap = true, silent = Copier.silence_output })
vim.api.nvim_set_keymap("n", "<leader>gg", ":lua Copier.fetch_clipboard()<CR>", { noremap = true, silent = Copier.silence_output })
