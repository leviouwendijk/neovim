local funcs = require("config.funcs")

return function(mark, ui)
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
    funcs.prompt_input(
        "Harpoon index: ",
        function(raw)
            local i = tonumber(raw)
            if i then
                ui.nav_file(i)
            else
                vim.notify(
                    "Invalid index: " .. tostring(raw),
                    vim.log.levels.WARN
                )
            end
        end
    )
end, { desc = "Harpoon: jump to index" })

-----------------------------------------------------------------------
-- Remove mark by index (v1-friendly):
-- Prompts for slot number, jumps to that file, and removes it.
-- (Harpoon v1's rm_file() targets the *current buffer*.)
-----------------------------------------------------------------------
vim.keymap.set("n", "<leader>hx", function()
    funcs.prompt_input(
        "Remove index: ",
        function(raw)
            local i = tonumber(raw)
            if not i then
                vim.notify(
                    "Invalid index: " .. tostring(raw),
                    vim.log.levels.WARN
                )
                return
            end

            -- Jump to the slot (no-op if out of range)
            ui.nav_file(i)
            -- Remove whatever is now current
            mark.rm_file()
            vim.notify(
                ("Harpoon: removed slot %d (if it existed)"):format(i),
                vim.log.levels.INFO
            )
        end
    )
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
end
