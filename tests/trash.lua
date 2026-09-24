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
        "picker_requires_move_and_enter_and_disables_overlays",
        function()
            local previous_cmp = package.loaded["cmp"]
            local previous_trash = package.loaded["core.trash"]
            local previous_netrw_trash = _G.NetrwTrash
            local previous_test_absolute = _G.TestAbsoluteFilepath
            local previous_has_executable = funcs.has_executable

            ---@type { buffer: integer, config: { experimental: { ghost_text: boolean } } }|nil
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

                rawset(
                    funcs,
                    "has_executable",
                    previous_has_executable
                )
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

                rawset(
                    funcs,
                    "has_executable",
                    function()
                        return true
                    end
                )

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
                    "nofile",
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
                assert(configured ~= nil)
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

                expect.equal(
                    before[4],
                    "  Move to Trash"
                )
                expect.equal(
                    before[5],
                    "  Cancel"
                )
                expect.equal(
                    vim.api.nvim_win_get_cursor(
                        picker_win
                    )[1],
                    5,
                    "trash picker defaults to Cancel"
                )

                expect.nil_value(
                    mapping_for(
                        picker_buf,
                        "y"
                    ),
                    "trash picker has no direct confirm key"
                )

                local enter =
                    mapping_for(
                        picker_buf,
                        "<CR>"
                    )
                local j = mapping_for(picker_buf, "j")
                local k = mapping_for(picker_buf, "k")

                expect.not_nil(
                    enter,
                    "trash picker Enter mapping"
                )
                expect.not_nil(j, "trash picker j mapping")
                expect.not_nil(k, "trash picker k mapping")

                local j_callback =
                    j and j.callback
                local k_callback =
                    k and k.callback

                expect.truthy(
                    type(j_callback) == "function",
                    "trash picker j mapping uses Lua callback"
                )
                expect.truthy(
                    type(k_callback) == "function",
                    "trash picker k mapping uses Lua callback"
                )

                assert(type(j_callback) == "function")
                assert(type(k_callback) == "function")

                k_callback()

                expect.equal(
                    vim.api.nvim_win_get_cursor(
                        picker_win
                    )[1],
                    4,
                    "confirming requires moving to destructive choice"
                )

                for _ = 1, 128 do
                    j_callback()
                    k_callback()
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

    testing.test(
        "detects_macos_and_xdg_trash_contents_without_matching_root",
        function()
            local previous_xdg =
                vim.env.XDG_DATA_HOME
            local xdg =
                vim.fn.tempname()

            vim.env.XDG_DATA_HOME = xdg

            local trash =
                require("core.trash")
            local home_trash =
                vim.fs.joinpath(
                    vim.uv.os_homedir() or "",
                    ".Trash"
                )
            local xdg_trash =
                vim.fs.joinpath(
                    xdg,
                    "Trash",
                    "files"
                )

            local ok, err =
                pcall(
                    function()
                        expect.truthy(
                            trash.is_in_trash(
                                vim.fs.joinpath(
                                    home_trash,
                                    "entry.txt"
                                )
                            ),
                            "macOS trash contents are detected"
                        )
                        expect.falsy(
                            trash.is_in_trash(
                                home_trash
                            ),
                            "trash root itself is not an item"
                        )

                        expect.truthy(
                            trash.is_in_trash(
                                vim.fs.joinpath(
                                    xdg_trash,
                                    "entry.txt"
                                )
                            ),
                            "XDG trash contents are detected"
                        )
                        expect.falsy(
                            trash.is_in_trash(
                                xdg_trash
                            ),
                            "XDG trash root itself is not an item"
                        )
                    end
                )

            vim.env.XDG_DATA_HOME =
                previous_xdg

            if not ok then
                error(err, 0)
            end
        end
    ),

    testing.test(
        "permanent_delete_unlinks_symlink_and_removes_directory_tree",
        function()
            local trash =
                require("core.trash")
            local root =
                vim.fn.tempname()
            local target =
                root .. "/target.txt"
            local link =
                root .. "/link.txt"
            local tree =
                root .. "/tree"

            local ok, err =
                pcall(
                    function()
                        vim.fn.mkdir(
                            tree .. "/nested",
                            "p"
                        )
                        vim.fn.writefile(
                            { "target" },
                            target
                        )
                        vim.fn.writefile(
                            { "nested" },
                            tree
                                .. "/nested/file.txt"
                        )

                        local linked, link_error =
                            vim.uv.fs_symlink(
                                target,
                                link
                            )
                        expect.truthy(
                            linked,
                            tostring(link_error)
                        )

                        local deleted_link,
                            delete_link_error =
                            trash.permanent_delete(
                                link
                            )
                        expect.truthy(
                            deleted_link,
                            tostring(
                                delete_link_error
                            )
                        )
                        expect.nil_value(
                            vim.uv.fs_lstat(link),
                            "symlink entry is removed"
                        )
                        expect.not_nil(
                            vim.uv.fs_stat(target),
                            "symlink target survives"
                        )

                        local deleted_tree,
                            delete_tree_error =
                            trash.permanent_delete(
                                tree
                            )
                        expect.truthy(
                            deleted_tree,
                            tostring(
                                delete_tree_error
                            )
                        )
                        expect.nil_value(
                            vim.uv.fs_lstat(tree),
                            "directory tree is removed recursively"
                        )
                    end
                )

            pcall(
                vim.fn.delete,
                root,
                "rf"
            )

            if not ok then
                error(err, 0)
            end
        end
    ),

    testing.test(
        "trash_item_requires_two_move_enter_confirmations_for_permanent_delete",
        function()
            local previous_cmp =
                package.loaded["cmp"]
            local previous_trash =
                package.loaded["core.trash"]
            local previous_netrw_trash =
                _G.NetrwTrash
            local previous_test_absolute =
                _G.TestAbsoluteFilepath
            local previous_has_executable =
                funcs.has_executable
            local previous_xdg =
                vim.env.XDG_DATA_HOME

            local fixture_root =
                vim.fn.tempname()
            local trash_files =
                fixture_root
                .. "/Trash/files"
            local filepath =
                trash_files
                .. "/entry.txt"
            local source_buf = nil
            local has_executable_calls = 0

            local function cleanup()
                for _, win in ipairs(
                    vim.api.nvim_list_wins()
                ) do
                    local buf =
                        vim.api.nvim_win_get_buf(
                            win
                        )

                    if
                        vim.bo[buf].filetype
                        == "trash-confirm"
                    then
                        pcall(
                            vim.api.nvim_win_close,
                            win,
                            true
                        )
                    end
                end

                if
                    source_buf
                    and vim.api.nvim_buf_is_valid(
                        source_buf
                    )
                then
                    pcall(
                        vim.api.nvim_buf_delete,
                        source_buf,
                        {
                            force = true,
                        }
                    )
                end

                pcall(
                    vim.fn.delete,
                    fixture_root,
                    "rf"
                )

                vim.env.XDG_DATA_HOME =
                    previous_xdg

                rawset(
                    funcs,
                    "has_executable",
                    previous_has_executable
                )
                package.loaded["cmp"] =
                    previous_cmp
                package.loaded["core.trash"] =
                    previous_trash
                _G.NetrwTrash =
                    previous_netrw_trash
                _G.TestAbsoluteFilepath =
                    previous_test_absolute
            end

            local ok, err =
                pcall(
                    function()
                        vim.env.XDG_DATA_HOME =
                            fixture_root
                        vim.fn.mkdir(
                            trash_files,
                            "p"
                        )
                        vim.fn.writefile(
                            { "delete me" },
                            filepath
                        )

                        package.loaded["cmp"] = {
                            setup = {
                                buffer =
                                    function() end,
                            },
                        }

                        rawset(
                            funcs,
                            "has_executable",
                            function()
                                has_executable_calls =
                                    has_executable_calls
                                    + 1
                                return false
                            end
                        )

                        package.loaded["core.trash"] =
                            nil

                        source_buf =
                            vim.api.nvim_create_buf(
                                false,
                                true
                            )
                        vim.api.nvim_set_current_buf(
                            source_buf
                        )
                        vim.api.nvim_buf_set_name(
                            source_buf,
                            trash_files .. "/"
                        )
                        vim.api.nvim_buf_set_lines(
                            source_buf,
                            0,
                            -1,
                            false,
                            {
                                "entry.txt",
                            }
                        )

                        require("core.trash")
                        _G.NetrwTrash(false)

                        local first_buf =
                            vim.api.nvim_get_current_buf()
                        local first_win =
                            vim.api.nvim_get_current_win()
                        local first_lines =
                            vim.api.nvim_buf_get_lines(
                                first_buf,
                                0,
                                -1,
                                false
                            )

                        expect.equal(
                            first_lines[4],
                            "  Permanently delete"
                        )
                        expect.equal(
                            first_lines[5],
                            "  Cancel"
                        )
                        expect.equal(
                            vim.api.nvim_win_get_cursor(
                                first_win
                            )[1],
                            5,
                            "first permanent-delete prompt defaults to Cancel"
                        )
                        expect.not_nil(
                            vim.uv.fs_lstat(
                                filepath
                            ),
                            "first prompt has not deleted the file"
                        )

                        local first_up =
                            mapping_for(
                                first_buf,
                                "k"
                            )
                        local first_enter =
                            mapping_for(
                                first_buf,
                                "<CR>"
                            )

                        expect.not_nil(first_up)
                        expect.not_nil(first_enter)
                        assert(
                            first_up
                                and type(first_up.callback)
                                    == "function"
                        )
                        assert(
                            first_enter
                                and type(first_enter.callback)
                                    == "function"
                        )

                        first_up.callback()
                        first_enter.callback()

                        local final_buf =
                            vim.api.nvim_get_current_buf()
                        local final_win =
                            vim.api.nvim_get_current_win()
                        local final_lines =
                            vim.api.nvim_buf_get_lines(
                                final_buf,
                                0,
                                -1,
                                false
                            )

                        expect.equal(
                            final_lines[4],
                            "  Delete permanently"
                        )
                        expect.equal(
                            final_lines[5],
                            "  Cancel"
                        )
                        expect.truthy(
                            final_lines[2]:find(
                                "This cannot be undone.",
                                1,
                                true
                            ) ~= nil,
                            "final confirmation states irreversibility"
                        )
                        expect.equal(
                            vim.api.nvim_win_get_cursor(
                                final_win
                            )[1],
                            5,
                            "final confirmation also defaults to Cancel"
                        )
                        expect.not_nil(
                            vim.uv.fs_lstat(
                                filepath
                            ),
                            "first confirmation alone does not delete"
                        )

                        local final_up =
                            mapping_for(
                                final_buf,
                                "k"
                            )
                        local final_enter =
                            mapping_for(
                                final_buf,
                                "<CR>"
                            )

                        expect.not_nil(final_up)
                        expect.not_nil(final_enter)
                        assert(
                            final_up
                                and type(final_up.callback)
                                    == "function"
                        )
                        assert(
                            final_enter
                                and type(final_enter.callback)
                                    == "function"
                        )

                        final_up.callback()
                        final_enter.callback()

                        expect.nil_value(
                            vim.uv.fs_lstat(
                                filepath
                            ),
                            "file is removed only after both confirmations"
                        )
                        expect.equal(
                            has_executable_calls,
                            0,
                            "permanent deletion does not require trash helper"
                        )
                    end
                )

            cleanup()

            if not ok then
                error(err, 0)
            end
        end
    ),
}, {
    title = "Trash",
})
