local testing = require("testing")
local expect = testing.expect
local picker = require("interface.trash")

local function mapping(buffer, key)
    -- Neovim may render <C-d> as <C-D> in mapping metadata.
    -- Compare decoded keycodes rather than display spellings.
    local decode = vim.api.nvim_replace_termcodes
    local wanted = decode(key, true, true, true)
    for _, item in ipairs(vim.api.nvim_buf_get_keymap(buffer, "n")) do
        if decode(item.lhs, true, true, true) == wanted then
            return expect.not_nil(item.callback, key .. " callback")
        end
    end
    error("Missing Trash UI mapping: " .. key)
end

local function paths(count)
    local result = {}
    for i = 1, count do
        result[i] = ("/tmp/trash-ui-tests/file-%03d.txt"):format(i)
    end
    return result
end

local function live_resize_count()
    return #vim.api.nvim_get_autocmds({ event = "VimResized" })
end

return testing.suite("trash_ui", {
    testing.test("layout_pages_without_moving_actions_or_wrapping", function()
        local selected = paths(27)
        local first = picker.layout("Trash 27 entries?", {
            preview_paths = selected,
        }, 80, 17, 0)
        expect.equal(first.lines[4], "  Move to Trash")
        expect.equal(first.lines[5], "  Cancel")
        expect.equal(first.page_size, 4)
        expect.equal(first.height, 13)
        expect.truthy(first.lines[9]:find("1-4 of 27", 1, true) ~= nil)
        expect.truthy(first.lines[10]:find("file-001", 1, true) ~= nil)
        local second = picker.layout("Trash 27 entries?", {
            preview_paths = selected,
        }, 80, 17, 3)
        expect.equal(second.lines[4], first.lines[4])
        expect.equal(second.lines[5], first.lines[5])
        expect.truthy(second.lines[9]:find("4-7 of 27", 1, true) ~= nil)
        expect.truthy(second.lines[10]:find("file-004", 1, true) ~= nil)
        expect.truthy(second.width <= 76)
        expect.equal(#second.lines, second.height)
    end),

    testing.test("preview_scrolling_does_not_navigate_actions", function()
        local ok, err = pcall(function()
            local chosen = nil
            expect.truthy(picker.open("Trash batch?", function(choice)
                chosen = choice
            end, 1, { preview_paths = paths(vim.o.lines + 20) }))
            local buf = vim.api.nvim_get_current_buf()
            local win = vim.api.nvim_get_current_win()
            local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            expect.equal(vim.api.nvim_win_get_cursor(win)[1], 5)
            mapping(buf, "<C-d>")()
            local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            expect.equal(after[4], before[4])
            expect.equal(after[5], before[5])
            expect.equal(vim.api.nvim_win_get_cursor(win)[1], 5)
            expect.not_equal(after[9], before[9], "scroll count changes")
            mapping(buf, "<C-u>")()
            expect.equal(vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1],
                before[9], "scrolling backward restores first page")
            mapping(buf, "<CR>")()
            expect.equal(chosen, "No", "Enter still cancels by default")
            expect.falsy(vim.api.nvim_win_is_valid(win))
        end)
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "trash-confirm" then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
        if not ok then error(err, 0) end
    end),

    testing.test("resize_and_external_close_release_autocmd", function()
        local before = live_resize_count()
        local ok, err = pcall(function()
            expect.truthy(picker.open("Trash batch?", function() end, 1,
                { preview_paths = paths(40) }))
            local win = vim.api.nvim_get_current_win()
            local buf = vim.api.nvim_get_current_buf()
            expect.equal(live_resize_count(), before + 1)
            vim.api.nvim_exec_autocmds("VimResized", { modeline = false })
            expect.truthy(vim.api.nvim_win_is_valid(win))
            expect.truthy(vim.api.nvim_win_get_width(win) <= vim.o.columns - 4)
            expect.equal(vim.api.nvim_win_get_cursor(win)[1], 5)
            -- Closing the window through a different route must also clean up.
            vim.api.nvim_win_close(win, true)
            expect.truthy(vim.wait(200, function()
                return live_resize_count() == before
            end, 10), "resize hook must be removed on external close")
            expect.falsy(vim.api.nvim_buf_is_valid(buf), "scratch buffer wiped")
        end)
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "trash-confirm" then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
        if not ok then error(err, 0) end
    end),
}, { title = "Trash confirmation UI" })
