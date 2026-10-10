local testing = require("testing")
local expect = testing.expect

return testing.suite("performance hot paths", {
    testing.test("word_count_cache_invalidates_on_edit_and_is_per_buffer", function()
        local wc = require("utils.word-count")
        local a = vim.api.nvim_create_buf(false, true)
        local b = vim.api.nvim_create_buf(false, true)
        local ok, err = pcall(function()
            vim.api.nvim_buf_set_lines(a, 0, -1, false, {
                "one two", "@document.meta", "ignored words", "@end", "three",
            })
            vim.api.nvim_buf_set_lines(b, 0, -1, false, { "different" })
            expect.equal(wc.count_current_buf(a), 3)
            expect.equal(wc.count_current_buf(a), 3)
            expect.equal(wc.count_current_buf(b), 1)
            vim.api.nvim_buf_set_lines(a, 0, 1, false, { "one two four" })
            expect.equal(wc.count_current_buf(a), 4)
            expect.equal(wc.count_current_buf(b), 1)
        end)
        vim.api.nvim_buf_delete(a, { force = true })
        vim.api.nvim_buf_delete(b, { force = true })
        if not ok then error(err, 0) end
    end),

    testing.test("netrw_metadata_does_not_rescan_on_unchanged_cursor_movement", function(context)
        local f = context:fixture({
            directories = { "root", "root/child" },
            files = { ["root/a.txt"] = "a" },
        })
        local stats = require("core.filetype.stats")
        local original = stats.get_filetype_virtualtext
        local calls = 0
        local old_render = package.loaded["core.filetype.render"]
        local render = require("core.filetype.render")
        local old_buf = vim.api.nvim_get_current_buf()
        local scratch = vim.api.nvim_create_buf(false, true)
        local ok, err = pcall(function()
            vim.api.nvim_set_current_buf(scratch)
            vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "child/", "a.txt" })
            vim.b[scratch].netrw_curdir = f:path("root")
            vim.bo[scratch].filetype = "netrw"
            stats.get_filetype_virtualtext = function(...)
                calls = calls + 1
                return original(...)
            end
            render.refresh()
            local before = calls
            expect.truthy(before > 0, "directory is scanned on initial render")
            vim.api.nvim_exec_autocmds("CursorMoved", {})
            expect.equal(calls, before, "unchanged listing is reused on cursor movement")
            vim.bo[scratch].modifiable = true
            vim.api.nvim_buf_set_lines(scratch, 1, 2, false, { "a.txt ", "a.txt" })
            render.refresh()
            expect.truthy(calls > before, "changedtick invalidates cached rendering")
        end)
        stats.get_filetype_virtualtext = original
        if vim.api.nvim_buf_is_valid(old_buf) then vim.api.nvim_set_current_buf(old_buf) end
        if vim.api.nvim_buf_is_valid(scratch) then
            vim.api.nvim_buf_delete(scratch, { force = true })
        end
        if not old_render then
            pcall(vim.api.nvim_del_augroup_by_name, "NetrwMetadataRender")
            package.loaded["core.filetype.render"] = nil
        end
        if not ok then error(err, 0) end
    end),

    testing.test("bedrocks_root_is_configured_once_per_root", function()
        local old_depth = package.loaded["extensions.bedrocks-depth"]
        local old_statusline = package.loaded["customizations.statusline"]
        local old_option = vim.o.statusline
        local setup_count = 0
        local ok, err = pcall(function()
            package.loaded["extensions.bedrocks-depth"] = {
                setup = function() setup_count = setup_count + 1 end,
                status = function() return "breadcrumb" end,
                current_model = function() return nil end,
            }
            package.loaded["customizations.statusline"] = nil
            local statusline = require("customizations.statusline")
            statusline.setup({ mode = "right", show_words = false,
                bedrocks_root = "/tmp/test-bedrocks-root" })
            expect.equal(statusline.right(), "breadcrumb")
            expect.equal(statusline.right(), "breadcrumb")
            expect.equal(setup_count, 1)
        end)
        package.loaded["extensions.bedrocks-depth"] = old_depth
        package.loaded["customizations.statusline"] = old_statusline
        vim.o.statusline = old_option
        if not ok then error(err, 0) end
    end),

    testing.test("netrw_statusline_autocmd_is_not_duplicated", function()
        local old_module = package.loaded["interface.statusline.netrw"]
        require("interface.statusline.netrw")
        local buf = vim.api.nvim_create_buf(false, true)
        local ok, err = pcall(function()
            vim.api.nvim_buf_call(buf, function()
                vim.api.nvim_exec_autocmds("FileType", { pattern = "netrw" })
            end)
            local first = vim.api.nvim_get_autocmds({
                group = "NetrwStatuslineRefresh", event = "BufEnter", buffer = buf,
            })
            vim.api.nvim_buf_call(buf, function()
                vim.api.nvim_exec_autocmds("FileType", { pattern = "netrw" })
            end)
            local second = vim.api.nvim_get_autocmds({
                group = "NetrwStatuslineRefresh", event = "BufEnter", buffer = buf,
            })
            expect.equal(#first, 1)
            expect.equal(#second, 1)
            local cursor_hooks = vim.api.nvim_get_autocmds({
                group = "NetrwStatuslineRefresh", event = "CursorMoved", buffer = buf,
            })
            expect.equal(#cursor_hooks, 0)
        end)
        vim.api.nvim_buf_delete(buf, { force = true })
        if not old_module then
            pcall(vim.api.nvim_del_augroup_by_name, "NetrwStatuslineRefresh")
            package.loaded["interface.statusline.netrw"] = nil
        end
        if not ok then error(err, 0) end
    end),
})
