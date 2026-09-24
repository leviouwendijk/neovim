local testing = require("testing")
local expect = testing.expect
local core = require("extensions.file_rename.core")
local netrw = require("extensions.file_rename.netrw")
local rename = require("extensions.file-rename")
local uv = vim.uv or vim.loop

local function canonical_path(path)
    return uv.fs_realpath(path)
        or core.normalize_path(path)
end

local function capture_notifications(body)
    local previous_notify = vim.notify
    local notifications = {}

    rawset(vim, "notify", function(message, level, options)
        table.insert(notifications, {
            message = tostring(message),
            level = level,
            options = options,
        })
    end)

    local ok, err = pcall(body, notifications)

    rawset(vim, "notify", previous_notify)

    if not ok then
        error(err, 0)
    end

    return notifications
end

local root = vim.g.nvim_config_test_root
local fixture_spec = dofile(
    vim.fs.joinpath(
        root,
        "tests",
        "fixtures",
        "file_rename.lua"
    )
)

local function fixture(context)
    return context:fixture(fixture_spec)
end

local function source_directory(fixture_value)
    return fixture_value:path("source")
end

return testing.suite("file_rename", {
    testing.test(
        "renames_file_without_overwriting_destination",
        function(context)
            local f = fixture(context)
            local directory = source_directory(f)

            local result = core.rename_in_directory(
                directory,
                "file.txt",
                "renamed.txt"
            )

            expect.equal(
                result.status,
                "renamed"
            )
            expect.not_exists(
                f:path("source/file.txt")
            )
            expect.file_contents(
                f:path("source/renamed.txt"),
                "file\n"
            )
        end
    ),

    testing.test(
        "renames_directory_tree",
        function(context)
            local f = fixture(context)
            local directory = source_directory(f)

            local result = core.rename_in_directory(
                directory,
                "directory",
                "renamed-directory"
            )

            expect.equal(
                result.status,
                "renamed"
            )
            expect.not_exists(
                f:path("source/directory")
            )
            expect.file_contents(
                f:path(
                    "source/renamed-directory/child.txt"
                ),
                "child\n"
            )
            expect.file_contents(
                f:path(
                    "source/renamed-directory/nested/deep.txt"
                ),
                "deep\n"
            )
        end
    ),

    testing.test(
        "existing_destination_is_rejected",
        function(context)
            local f = fixture(context)
            local directory = source_directory(f)

            local result = core.rename_in_directory(
                directory,
                "file.txt",
                "existing.txt"
            )

            expect.equal(
                result.status,
                "error"
            )
            expect.equal(
                result.message,
                "Destination already exists"
            )
            expect.file_contents(
                f:path("source/file.txt"),
                "file\n"
            )
            expect.file_contents(
                f:path("source/existing.txt"),
                "existing\n"
            )
        end
    ),

    testing.test(
        "same_path_is_noop",
        function(context)
            local f = fixture(context)
            local directory = source_directory(f)

            local result = core.rename_in_directory(
                directory,
                "file.txt",
                "file.txt"
            )

            expect.equal(
                result.status,
                "noop"
            )
            expect.file_contents(
                f:path("source/file.txt"),
                "file\n"
            )
        end
    ),

    testing.test(
        "cancel_does_not_mutate_or_close_loaded_buffer",
        function(context)
            local f = fixture(context)
            local directory = source_directory(f)
            local source = f:path(
                "source/file.txt"
            )
            local previous_input = vim.ui.input
            local previous_buffer =
                vim.api.nvim_get_current_buf()

            local ok, err = pcall(function()
                vim.cmd(
                    "edit "
                        .. vim.fn.fnameescape(source)
                )

                local loaded =
                    vim.api.nvim_get_current_buf()

                rawset(vim.ui, "input", function(_, callback)
                    callback(nil)
                end)

                ---@type { status: string }|nil
                local completed = nil

                local notifications = capture_notifications(
                    function()
                        rename.request_rename(
                            directory,
                            "file.txt",
                            function(result)
                                completed = result
                            end
                        )
                    end
                )

                expect.equal(
                    #notifications,
                    0,
                    "cancel does not emit a notification"
                )
                expect.not_nil(
                    completed,
                    "cancel callback completed"
                )
                assert(completed ~= nil)
                expect.equal(
                    completed.status,
                    "cancelled"
                )
                expect.truthy(
                    vim.api.nvim_buf_is_valid(loaded),
                    "loaded source buffer remains valid"
                )
                expect.equal(
                    canonical_path(
                        vim.api.nvim_buf_get_name(
                            loaded
                        )
                    ),
                    canonical_path(source),
                    "loaded buffer still identifies source file"
                )
                expect.file_contents(
                    source,
                    "file\n"
                )
            end)

            vim.ui.input = previous_input

            if vim.api.nvim_buf_is_valid(
                previous_buffer
            ) then
                pcall(
                    vim.api.nvim_set_current_buf,
                    previous_buffer
                )
            end

            pcall(function()
                vim.cmd(
                    "silent! bwipeout! "
                        .. vim.fn.bufnr(source)
                )
            end)

            if not ok then
                error(err, 0)
            end
        end
    ),

    testing.test(
        "loaded_buffer_is_reconciled_and_eventignore_restored",
        function(context)
            local f = fixture(context)
            local directory = source_directory(f)
            local source = f:path(
                "source/file.txt"
            )
            local destination = f:path(
                "source/renamed.txt"
            )
            local previous_eventignore =
                vim.o.eventignore
            local previous_buffer =
                vim.api.nvim_get_current_buf()

            local ok, err = pcall(function()
                vim.cmd(
                    "edit "
                        .. vim.fn.fnameescape(source)
                )

                local loaded =
                    vim.api.nvim_get_current_buf()

                vim.o.eventignore = "CursorMoved"

                local result = rename.rename_entry(
                    directory,
                    "file.txt",
                    "renamed.txt"
                )

                expect.equal(
                    result.status,
                    "renamed"
                )
                expect.equal(
                    vim.o.eventignore,
                    "CursorMoved",
                    "eventignore is restored exactly"
                )
                expect.equal(
                    canonical_path(
                        vim.api.nvim_buf_get_name(
                            loaded
                        )
                    ),
                    canonical_path(destination),
                    "loaded buffer follows renamed file"
                )
                expect.not_exists(source)
                expect.file_contents(
                    destination,
                    "file\n"
                )
            end)

            vim.o.eventignore =
                previous_eventignore

            if vim.api.nvim_buf_is_valid(
                previous_buffer
            ) then
                pcall(
                    vim.api.nvim_set_current_buf,
                    previous_buffer
                )
            end

            local destination_buffer =
                vim.fn.bufnr(destination)

            if destination_buffer > 0 then
                pcall(
                    vim.api.nvim_buf_delete,
                    destination_buffer,
                    {
                        force = true,
                    }
                )
            end

            if not ok then
                error(err, 0)
            end
        end
    ),

    testing.test(
        "netrw_cursor_rename_refreshes_and_reselects_entry",
        function(context)
            local f = fixture(context)
            local directory = source_directory(f)
            local previous_input = vim.ui.input

            local ok, err = pcall(function()
                vim.cmd(
                    "silent Explore "
                        .. vim.fn.fnameescape(
                            directory
                        )
                )

                local opened = vim.wait(
                    500,
                    function()
                        return vim.bo.filetype
                            == "netrw"
                    end,
                    10
                )

                expect.truthy(
                    opened,
                    "Netrw opened"
                )

                local row = nil

                for index = 1,
                    vim.api.nvim_buf_line_count(0)
                do
                    vim.api.nvim_win_set_cursor(
                        0,
                        { index, 0 }
                    )

                    if netrw.entry_under_cursor()
                        == "file.txt"
                    then
                        row = index
                        break
                    end
                end

                expect.not_nil(
                    row,
                    "fixture file row exists"
                )

                vim.api.nvim_win_set_cursor(
                    0,
                    { row, 0 }
                )

                rawset(
                    vim.ui,
                    "input",
                    function(_, callback)
                        callback("renamed.txt")
                    end
                )

                local notifications = capture_notifications(
                    function()
                        rename.rename_cursor_file()
                    end
                )

                expect.equal(
                    #notifications,
                    1,
                    "successful cursor rename emits one notification"
                )
                expect.equal(
                    notifications[1].message,
                    "Renamed file.txt to renamed.txt",
                    "success notification contents"
                )

                expect.not_exists(
                    f:path("source/file.txt")
                )
                expect.file_contents(
                    f:path(
                        "source/renamed.txt"
                    ),
                    "file\n"
                )
                expect.equal(
                    vim.bo.filetype,
                    "netrw"
                )
                expect.equal(
                    netrw.entry_under_cursor(),
                    "renamed.txt",
                    "refreshed Netrw reselects renamed entry"
                )
            end)

            rawset(vim.ui, "input", previous_input)
            pcall(function()
                vim.cmd("silent enew")
            end)

            if not ok then
                error(err, 0)
            end
        end
    ),
}, {
    title = "File rename",
})
