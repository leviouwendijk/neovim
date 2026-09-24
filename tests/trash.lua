local testing = require("testing")
local expect = testing.expect
local funcs = require("config.funcs")
local indentation = require("extensions.indentation")

local function mapping_for(buffer, lhs)
    for _, mapping in ipairs(
        vim.api.nvim_buf_get_keymap(buffer, "n")
    ) do
        if mapping.lhs == lhs then
            return mapping
        end
    end

    return nil
end

return testing.suite("trash", {
    testing.test(
        "picker_is_stable_and_disables_overlays",
        function()
            local previous_cmp = package.loaded["cmp"]
            local previous_trash = package.loaded["core.trash"]
            local previous_netrw_trash = _G.NetrwTrash
            local previous_test_absolute = _G.TestAbsoluteFilepath
            local previous_has_executable = funcs.has_executable

            local configured = nil
            local source_buf = nil
            local picker_buf = nil
            local picker_win = nil
            local fixture_root = vim.fn.tempname()

            local function cleanup()
                indentation.set("none")

                if picker_win
                    and vim.api.nvim_win_is_valid(picker_win)
                then
                    pcall(
                        vim.api.nvim_win_close,
                        picker_win,
                        true
                    )
                end

                if source_buf
                    and vim.api.nvim_buf_is_valid(source_buf)
                then
                    pcall(
                        vim.api.nvim_buf_delete,
                        source_buf,
                        { force = true }
                    )
                end

                pcall(vim.fn.delete, fixture_root, "rf")

                funcs.has_executable = previous_has_executable
                package.loaded["cmp"] = previous_cmp
                package.loaded["core.trash"] = previous_trash
                _G.NetrwTrash = previous_netrw_trash
                _G.TestAbsoluteFilepath = previous_test_absolute
            end

            local ok, err = pcall(function()
                vim.fn.mkdir(fixture_root, "p")

                package.loaded["cmp"] = {
                    setup = {
                        buffer = function(config)
                            configured = {
                                buffer = vim.api.nvim_get_current_buf(),
                                config = config,
                            }
                        end,
                    },
                }

                funcs.has_executable = function()
                    return true
                end

                package.loaded["core.trash"] = nil

                source_buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_set_current_buf(source_buf)
                vim.api.nvim_buf_set_name(
                    source_buf,
                    fixture_root .. "/"
                )
                vim.api.nvim_buf_set_lines(
                    source_buf,
                    0,
                    -1,
                    false,
                    { "entry.txt" }
                )

                require("core.trash")
                _G.NetrwTrash(false)

                picker_buf = vim.api.nvim_get_current_buf()
                picker_win = vim.api.nvim_get_current_win()

                expect.not_equal(
                    picker_buf,
                    source_buf,
                    "trash picker opens its own buffer"
                )
                expect.equal(
                    vim.bo[picker_buf].buftype,
                    "prompt",
                    "trash picker buffer type"
                )
                expect.falsy(
                    vim.bo[picker_buf].modifiable,
                    "trash picker is immutable after rendering"
                )

                expect.not_nil(
                    configured,
                    "trash picker configured cmp"
                )
                expect.equal(
                    configured.buffer,
                    picker_buf,
                    "cmp override applies to picker buffer"
                )
                expect.falsy(
                    configured.config.experimental.ghost_text,
                    "trash picker disables cmp ghost text"
                )

                indentation.set("countdotsend")

                local indentation_ns =
                    vim.api.nvim_get_namespaces().indentation

                expect.not_nil(
                    indentation_ns,
                    "indentation namespace exists"
                )

                local indentation_marks =
                    vim.api.nvim_buf_get_extmarks(
                        picker_buf,
                        indentation_ns,
                        0,
                        -1,
                        {}
                    )

                expect.equal(
                    #indentation_marks,
                    0,
                    "prompt buffer has no indentation overlays"
                )

                local before = vim.api.nvim_buf_get_lines(
                    picker_buf,
                    0,
                    -1,
                    false
                )

                expect.equal(before[4], "  Yes")
                expect.equal(before[5], "  No")

                local j = mapping_for(picker_buf, "j")
                local k = mapping_for(picker_buf, "k")

                expect.not_nil(j, "trash picker j mapping")
                expect.not_nil(k, "trash picker k mapping")
                expect.truthy(
                    type(j.callback) == "function",
                    "trash picker j mapping uses Lua callback"
                )
                expect.truthy(
                    type(k.callback) == "function",
                    "trash picker k mapping uses Lua callback"
                )

                for _ = 1, 128 do
                    j.callback()
                    k.callback()
                end

                indentation.set("countdotsend")

                local after_marks =
                    vim.api.nvim_buf_get_extmarks(
                        picker_buf,
                        indentation_ns,
                        0,
                        -1,
                        {}
                    )

                expect.equal(
                    #after_marks,
                    0,
                    "rapid navigation cannot add indentation overlays"
                )

                local after = vim.api.nvim_buf_get_lines(
                    picker_buf,
                    0,
                    -1,
                    false
                )

                expect.truthy(
                    vim.deep_equal(after, before),
                    "rapid picker navigation preserves rendered lines"
                )
                expect.equal(
                    vim.api.nvim_win_get_cursor(picker_win)[1],
                    4,
                    "rapid picker navigation remains within choice rows"
                )
            end)

            cleanup()

            if not ok then
                error(err, 0)
            end
        end
    ),
}, {
    title = "Trash",
})
