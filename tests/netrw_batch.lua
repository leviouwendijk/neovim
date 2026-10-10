local testing = require("testing")
local expect = testing.expect
local selected = require("core.netrw-selection")
local funcs = require("config.funcs")
local uv = vim.uv or vim.loop

local function with_netrw(callback, extra_files)
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    for _, name in ipairs({ "a.txt", "b.txt", "c.txt" }) do
        vim.fn.writefile({ name }, vim.fs.joinpath(dir, name))
    end
    for _, name in ipairs(extra_files or {}) do
        vim.fn.writefile({ name }, vim.fs.joinpath(dir, name))
    end
    local old_style = vim.g.netrw_liststyle
    vim.g.netrw_liststyle = 0
    local ok, err = pcall(function()
        vim.cmd("silent Explore " .. vim.fn.fnameescape(dir))
        expect.truthy(vim.wait(500, function()
            return vim.bo.filetype == "netrw"
        end, 10), "netrw opened")
        selected.clear_marks()
        callback(dir)
    end)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "trash-confirm" then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end
    if vim.bo.filetype == "netrw" then selected.clear_marks() end
    vim.g.netrw_liststyle = old_style
    pcall(function() vim.cmd("silent enew") end)
    vim.fn.delete(dir, "rf")
    if not ok then error(err, 0) end
end

local function row_of(path)
    for row = 1, vim.api.nvim_buf_line_count(0) do
        if selected.entry_at_row(row) == path then return row end
    end
    error("Entry not found: " .. path)
end

local function mark(name)
    local path = vim.fs.joinpath(selected.active_directory(), name)
    vim.api.nvim_win_set_cursor(0, { row_of(path), 0 })
    local ok, err = pcall(vim.fn["netrw#Call"], "NetrwMarkFile", 1, name)
    expect.truthy(ok, tostring(err))
end

local function picker_callback(buffer, key)
    for _, entry in ipairs(vim.api.nvim_buf_get_keymap(buffer, "n")) do
        if entry.lhs == key then return entry.callback end
    end
    error("Missing picker mapping " .. key)
end

return testing.suite("netrw_batch", {
    testing.test("path_aliases_preserve_symlink_entry_identity", function()
        local root = vim.fn.tempname()
        local alias = root .. "-alias"
        vim.fn.mkdir(root, "p")
        local original = vim.fs.joinpath(root, "a.txt")
        local link = vim.fs.joinpath(root, "link.txt")
        vim.fn.writefile({ "contents" }, original)
        local alias_ok = uv.fs_symlink(root, alias)
        local link_ok = uv.fs_symlink(original, link)
        local ok, err = pcall(function()
            expect.truthy(alias_ok, "directory symlink created")
            expect.truthy(link_ok, "file symlink created")
            expect.truthy(selected.same_entry(original,
                vim.fs.joinpath(alias, "a.txt")), "aliased parent directories")
            expect.equal(selected.same_entry(original, link), false,
                "leaf symlink remains a distinct entry")
        end)
        if link_ok then uv.fs_unlink(link) end
        if alias_ok then uv.fs_unlink(alias) end
        vim.fn.delete(root, "rf")
        if not ok then error(err, 0) end
    end),

    testing.test("visual_overrides_marks_and_cursor_fallback", function()
        with_netrw(function(root)
            local a = vim.fs.joinpath(root, "a.txt")
            local b = vim.fs.joinpath(root, "b.txt")
            local c = vim.fs.joinpath(root, "c.txt")
            mark("c.txt")
            local raw_marked, kind = selected.resolve()
            local marked = expect.not_nil(raw_marked, "marked selection")
            expect.equal(kind, "marks")
            expect.equal(#marked, 1)
            expect.equal(marked[1], c)
            local raw_visual, visual_kind = selected.resolve({
                visual_rows = { row_of(a), row_of(b) },
            })
            local visual = expect.not_nil(raw_visual, "visual selection")
            expect.equal(visual_kind, "visual")
            expect.equal(#visual, 2)
            expect.equal(visual[1], a)
            expect.equal(visual[2], b)
            selected.clear_marks()
            vim.api.nvim_win_set_cursor(0, { row_of(b), 0 })
            local raw_cursor, cursor_kind = selected.resolve()
            local cursor = expect.not_nil(raw_cursor, "cursor selection")
            expect.equal(cursor_kind, "cursor")
            expect.equal(cursor[1], b)
        end)
    end),

    testing.test("refresh_preserves_previous_surviving_entry", function()
        with_netrw(function(root)
            local a = vim.fs.joinpath(root, "a.txt")
            local b = vim.fs.joinpath(root, "b.txt")
            vim.api.nvim_win_set_cursor(0, { row_of(b), 0 })
            local snapshot = selected.capture({ b })
            expect.equal(snapshot.anchor, a)
            expect.truthy(uv.fs_unlink(b))
            -- A netrw redraw may recreate its buffer even in the same window.
            snapshot.buffer = -1
            selected.refresh(snapshot)
            local row = vim.api.nvim_win_get_cursor(0)[1]
            expect.truthy(selected.same_entry(selected.entry_at_row(row), a),
                "refreshed cursor must target the previous surviving entry")
        end)
    end),

    testing.test("marked_trash_preview_and_cancel_keeps_marks", function()
        local old_has = funcs.has_executable
        local old_global = _G.NetrwTrash
        local old_module = package.loaded["core.trash"]
        local ok, err = pcall(function()
            rawset(funcs, "has_executable", function() return true end)
            package.loaded["core.trash"] = nil
            require("core.trash")
            with_netrw(function(root)
                mark("a.txt")
                mark("c.txt")
                _G.NetrwTrash()
                local picker = vim.api.nvim_get_current_buf()
                local lines = vim.api.nvim_buf_get_lines(picker, 0, -1, false)
                local content = table.concat(lines, "\n")
                expect.truthy(content:find("a.txt", 1, true) ~= nil)
                expect.truthy(content:find("c.txt", 1, true) ~= nil)
                expect.equal(lines[4], "  Move to Trash")
                expect.equal(lines[5], "  Cancel")
                expect.equal(vim.api.nvim_win_get_cursor(0)[1], 5)
                picker_callback(picker, "<Esc>")()
                expect.exists(vim.fs.joinpath(root, "a.txt"))
                expect.exists(vim.fs.joinpath(root, "c.txt"))
                local marks, kind = selected.resolve()
                expect.equal(kind, "marks")
                expect.equal(#marks, 2)
            end)
        end)
        rawset(funcs, "has_executable", old_has)
        package.loaded["core.trash"] = old_module
        _G.NetrwTrash = old_global
        if not ok then error(err, 0) end
    end),
    testing.test("long_trash_previews_expand_without_wrapping", function()
        local long_name =
            "a_file_with_a_name_exceeding_the_old_forty_two_column_dialog.json"
        local old_has = funcs.has_executable
        local old_global = _G.NetrwTrash
        local old_module = package.loaded["core.trash"]
        local ok, err = pcall(function()
            rawset(funcs, "has_executable", function() return true end)
            package.loaded["core.trash"] = nil
            require("core.trash")
            with_netrw(function(root)
                local long_path = vim.fs.joinpath(root, long_name)
                mark("a.txt")
                mark(long_name)
                _G.NetrwTrash()

                local picker = vim.api.nvim_get_current_buf()
                local lines = vim.api.nvim_buf_get_lines(picker, 0, -1, false)
                local preview_line = "  " .. vim.fn.fnamemodify(long_path, ":~:.")
                local expected_width = math.min(
                    math.max(1, vim.o.columns - 4),
                    96,
                    vim.fn.strdisplaywidth(preview_line) + 2
                )
                expect.truthy(
                    vim.api.nvim_win_get_width(0) >= expected_width,
                    "picker must size to path content within its width cap"
                )
                expect.equal(vim.wo.wrap, false, "picker must not wrap paths")
                expect.truthy(
                    table.concat(lines, "\n"):find(long_name, 1, true) ~= nil,
                    "long path remains available in the preview"
                )
                if #lines <= vim.o.lines - 4 then
                    expect.equal(vim.api.nvim_win_get_height(0), #lines,
                        "one buffer line must occupy one viewport row")
                end
                expect.equal(vim.api.nvim_win_get_cursor(0)[1], 5,
                    "Cancel remains the default")
                picker_callback(picker, "<Esc>")()
            end, { long_name })
        end)
        rawset(funcs, "has_executable", old_has)
        package.loaded["core.trash"] = old_module
        _G.NetrwTrash = old_global
        if not ok then error(err, 0) end
    end),

    testing.test("confirmed_marked_batch_refreshes_to_preceding_entry", function()
        local old_system = vim.system
        local old_has = funcs.has_executable
        local old_global = _G.NetrwTrash
        local old_module = package.loaded["core.trash"]
        local ok, err = pcall(function()
            rawset(funcs, "has_executable", function() return true end)
            package.loaded["core.trash"] = nil
            require("core.trash")
            with_netrw(function(root)
                local a = vim.fs.joinpath(root, "a.txt")
                local b = vim.fs.joinpath(root, "b.txt")
                local c = vim.fs.joinpath(root, "c.txt")
                mark("b.txt")
                mark("c.txt")
                vim.api.nvim_win_set_cursor(0, { row_of(c), 0 })
                rawset(vim, "system", function(argv, _, callback)
                    expect.equal(#argv, 3)
                    expect.equal(argv[1], "trash")
                    for i = 2, #argv do
                        expect.truthy(uv.fs_unlink(argv[i]))
                    end
                    callback({ code = 0, stdout = "", stderr = "" })
                    return { kill = function() end }
                end)
                _G.NetrwTrash()
                local picker = vim.api.nvim_get_current_buf()
                picker_callback(picker, "k")()
                picker_callback(picker, "<CR>")()
                local completed = vim.wait(1000, function()
                    return not uv.fs_lstat(b) and not uv.fs_lstat(c)
                        and vim.bo.filetype == "netrw"
                        and selected.same_entry(selected.entry_at_row(
                            vim.api.nvim_win_get_cursor(0)[1]), a)
                end, 10)
                expect.truthy(completed, "batch refresh retains previous item")
                local raw_remaining, kind = selected.resolve()
                local remaining = expect.not_nil(raw_remaining, "post-batch selection")
                expect.equal(kind, "cursor", "successful batch clears marks")
                expect.truthy(selected.same_entry(remaining[1], a),
                    "post-batch cursor selects preceding survivor")
            end)
        end)
        rawset(vim, "system", old_system)
        rawset(funcs, "has_executable", old_has)
        package.loaded["core.trash"] = old_module
        _G.NetrwTrash = old_global
        if not ok then error(err, 0) end
    end),
}, { title = "Netrw batch selection" })
