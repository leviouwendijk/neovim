local funcs = require("config.funcs")

-- local harpoon = require("harpoon")
local harpoon = funcs.require_or_nil("harpoon",
    {
        message = "harpoon missing; skipping setup",
    }
)

if not harpoon then
    return
end

harpoon:setup({
    settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
    },
})

-- v2-compatible 'mark' shim
local mark = {}

local function _harpoon_menu_is_open()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
        if ft == "harpoon" then return true end
    end
    return false
end

local function _harpoon_menu_refresh()
    local list = harpoon:list()
    harpoon.ui:toggle_quick_menu(list)
    harpoon.ui:toggle_quick_menu(list)
end

-- v2 add with notify + live refresh; works for current buffer or explicit path
function mark.add_file(path)
    local list = harpoon:list()
    local p = path or vim.api.nvim_buf_get_name(0)
    if p == "" then
        vim.notify("Harpoon: no file to add (empty buffer)", vim.log.levels.WARN, { title = "Harpoon" })
        return
    end

    -- already in list? tell slot & refresh if menu is open
    for i, it in ipairs(list.items) do
        if it.value == p then
            vim.notify(("Harpoon: already in list (slot %d)"):format(i), vim.log.levels.INFO, { title = "Harpoon" })
            if _harpoon_menu_is_open() then _harpoon_menu_refresh() end
            return
        end
    end

    if path then
        list:add({ value = p })    -- explicit path must be wrapped
    else
        list:add()                 -- current buffer
    end

    -- find slot + notify
    local idx
    for i, it in ipairs(list.items) do
        if it.value == p then idx = i; break end
    end
    local pretty = vim.fn.fnamemodify(p, ":.")
    vim.notify(("Harpoon: added → %s%s"):format(idx and (idx .. ". ") or "", pretty),
        vim.log.levels.INFO, { title = "Harpoon" })

    if _harpoon_menu_is_open() then _harpoon_menu_refresh() end
end

function mark.rm_file(path)
    local list = harpoon:list()
    if path and #path > 0 then
        -- remove by path (find index first)
        for i, it in ipairs(list.items) do
            if it.value == path then
                list:remove_at(i)
                return
            end
        end
    else
        -- remove current buffer
        list:remove()
    end
end

function mark.clear_all()
    harpoon:list():clear()
end

function mark.set_current_at(i)
    harpoon:list():replace_at(i)
end

function mark.get_marked_file_list()
    local items = harpoon:list().items
    local out = {}
    for i, it in ipairs(items) do out[i] = it.value end
    return out
end

function mark.get_current_index()
    local curr = vim.api.nvim_buf_get_name(0)
    if curr == "" then return nil end
    for i, it in ipairs(harpoon:list().items) do
        if it.value == curr then return i end
    end
    return nil
end

-- v2-compatible 'ui' shim
local ui = {}

function ui.toggle_quick_menu()
    harpoon.ui:toggle_quick_menu(harpoon:list())
end

function ui.nav_file(i)
    harpoon:list():select(i)
end

function ui.nav_next()
    harpoon:list():next()
end

function ui.nav_prev()
    harpoon:list():prev()
end

-- vim.keymap.set("n", "<leader>a", mark.add_file)
vim.keymap.set("n", "<leader>ha", mark.add_file)

vim.keymap.set("n", "<C-d>", ui.toggle_quick_menu)
vim.keymap.set("n", "<C-x>", ui.toggle_quick_menu)
-- note: not working with ghostty properly

vim.keymap.set("n", "<leader>hf", ui.toggle_quick_menu)

-- vim.keymap.set("n", "<C-h>", function() ui.nav_file(1) end)
-- vim.keymap.set("n", "<C-j>", function() ui.nav_file(2) end)
-- vim.keymap.set("n", "<C-k>", function() ui.nav_file(3) end)
-- vim.keymap.set("n", "<C-l>", function() ui.nav_file(4) end)
-- vim.keymap.set("n", "<C-;>", function() ui.nav_file(5) end)

vim.keymap.set("n", "<C-j>", function() ui.nav_file(1) end)
vim.keymap.set("n", "<C-k>", function() ui.nav_file(2) end)
vim.keymap.set("n", "<C-l>", function() ui.nav_file(3) end)
vim.keymap.set("n", "<C-;>", function() ui.nav_file(4) end)

vim.keymap.set("n", "<C-u>", function() ui.nav_file(5) end)
vim.keymap.set("n", "<C-i>", function() ui.nav_file(6) end)
vim.keymap.set("n", "<C-o>", function() ui.nav_file(7) end)
-- vim.keymap.set("n", "<C-p>", function() ui.nav_file(8) end) -- conflicts with alt copy remap

for i = 1, 9 do
    vim.keymap.set("n", "<leader>" .. i, function() ui.nav_file(i) end)
end

vim.keymap.set("n", "]h", ui.nav_next)
vim.keymap.set("n", "[h", ui.nav_prev)

vim.keymap.set("n", "<leader>hr", mark.rm_file)
vim.keymap.set("n", "<leader>hC", mark.clear_all)

vim.api.nvim_create_autocmd("FileType", {
    pattern = "harpoon",
    callback = function(ev)
        vim.keymap.set("n", "dd", function()
            local line = vim.api.nvim_get_current_line()
            local path = line:match("^%s*%d+%.%s+(.*)$")
            if path and #path > 0 then
                mark.rm_file(path)
                ui.toggle_quick_menu()
                ui.toggle_quick_menu()
            else
                vim.notify("No file on this line", vim.log.levels.WARN)
            end
        end, { buffer = ev.buf, silent = true })
    end,
})

-----------------------------------------------------------------------
-- Prompted jump to a specific Harpoon index (without adding mappings
-- for all slots): asks for a number, then jumps to that file.
-----------------------------------------------------------------------
vim.keymap.set("n", "<leader>hj", function()
    local raw = vim.fn.input("Harpoon index: ")
    local i = tonumber(raw)
    if i then
        ui.nav_file(i)
    else
        vim.notify("Invalid index: " .. tostring(raw), vim.log.levels.WARN)
    end
end, { desc = "Harpoon: jump to index" })

-----------------------------------------------------------------------
-- Remove mark by index (v1-friendly):
-- Prompts for slot number, jumps to that file, and removes it.
-- (Harpoon v1's rm_file() targets the *current buffer*.)
-----------------------------------------------------------------------
vim.keymap.set("n", "<leader>hx", function()
    local raw = vim.fn.input("Remove index: ")
    local i = tonumber(raw)
    if not i then
        vim.notify("Invalid index: " .. tostring(raw), vim.log.levels.WARN)
        return
    end
    -- Jump to the slot (no-op if out of range)
    ui.nav_file(i)
    -- Remove whatever is now current
    mark.rm_file()
    vim.notify(("Harpoon: removed slot %d (if it existed)"):format(i), vim.log.levels.INFO)
end, { desc = "Harpoon: remove by index" })

-----------------------------------------------------------------------
-- Quick picker using built-in vim.ui.select (no Telescope needed):
-- Presents the marked files and jumps to the chosen one.
-----------------------------------------------------------------------
vim.keymap.set("n", "<leader>hp", function()
    local list = mark.get_marked_file_list()
    if not list or #list == 0 then
        vim.notify("Harpoon: no marks yet", vim.log.levels.INFO)
        return
    end

    local items = {}
    for i, path in ipairs(list) do
        items[i] = string.format("%d. %s", i, path)
    end

    vim.ui.select(items, { prompt = "Harpoon marks:" }, function(choice, idx)
        if idx then ui.nav_file(idx) end
    end)
end, {
        desc = "Harpoon: pick from list"
    }
)

-----------------------------------------------------------------------
-- Pin current buffer to a specific slot:
-- Lets you assign the current file to slot 1..9 (overwrite that slot).
-----------------------------------------------------------------------
for i = 1, 9 do
    vim.keymap.set("n", "<leader>h" .. i, function()
        mark.set_current_at(i)
        vim.notify(("Harpoon: pinned current file to slot %d"):format(i), vim.log.levels.INFO)
    end, { desc = ("Harpoon: pin to %d"):format(i) })
end

-----------------------------------------------------------------------
-- Statusline helper to show Harpoon position for the current buffer:
-- Returns "H:idx/len" if current buffer is marked, else "".
-- Use in lualine as: { function() return _G.HarpoonV1Status() end }
-----------------------------------------------------------------------
function _G.HarpoonStatus()
    local curr = vim.api.nvim_buf_get_name(0)
    if curr == "" then return "" end

    -- Prefer Harpoon v1's helper if available; fall back to manual scan.
    local ok_idx, idx = pcall(mark.get_current_index)
    if ok_idx and type(idx) == "number" then
        local list = mark.get_marked_file_list() or {}
        if idx >= 1 and idx <= #list then
            return ("H:%d/%d"):format(idx, #list)
        end
    else
        local list = mark.get_marked_file_list() or {}
        for i, p in ipairs(list) do
            if p == curr then
                return ("H:%d/%d"):format(i, #list)
            end
        end
    end
    return ""
end

-----------------------------------------------------------------------
-- Extra niceties inside the Harpoon quick menu buffer:
--  • 'q' closes the menu buffer quickly.
--  • (keeps your existing 'dd' to delete-under-cursor behavior)
-----------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
    pattern = "harpoon",
    callback = function(ev)
        vim.keymap.set("n", "q", "<cmd>bd!<CR>", { buffer = ev.buf, silent = true, desc = "Close Harpoon menu" })
    end,
})
