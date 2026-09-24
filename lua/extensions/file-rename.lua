local core = require("extensions.file_rename.core")
local netrw = require("extensions.file_rename.netrw")
local funcs = require("config.funcs")

local M = {}

local function eventignore_with(previous, additions)
    if previous == "all" then
        return previous
    end

    local values = {}
    local seen = {}

    for value in tostring(previous):gmatch("[^,]+") do
        if value ~= "" and not seen[value] then
            seen[value] = true
            table.insert(values, value)
        end
    end

    for _, value in ipairs(additions) do
        if not seen[value] then
            seen[value] = true
            table.insert(values, value)
        end
    end

    return table.concat(values, ",")
end

local function reconcile_buffer(
    source,
    destination
)
    local buffer = vim.fn.bufnr(source)

    if buffer <= 0
        or not vim.api.nvim_buf_is_valid(buffer)
    then
        return true
    end

    local previous = vim.o.eventignore
    vim.o.eventignore = eventignore_with(
        previous,
        {
            "BufFilePre",
            "BufFilePost",
        }
    )

    local ok, err = pcall(
        vim.api.nvim_buf_set_name,
        buffer,
        destination
    )

    vim.o.eventignore = previous

    return ok, err
end

local function destination_buffer_conflict(
    source,
    destination
)
    local source_buffer = vim.fn.bufnr(source)
    local destination_buffer =
        vim.fn.bufnr(destination)

    return destination_buffer > 0
        and destination_buffer ~= source_buffer
        and vim.api.nvim_buf_is_valid(
            destination_buffer
        )
end

function M.rename_entry(
    directory,
    old_name,
    new_name
)
    local source = core.destination_for(
        directory,
        old_name
    )
    local destination = core.destination_for(
        directory,
        new_name
    )

    if not source or not destination then
        return {
            status = "error",
            source = source,
            destination = destination,
            message = "Invalid rename path",
        }
    end

    if destination_buffer_conflict(
        source,
        destination
    ) then
        return {
            status = "error",
            source = source,
            destination = destination,
            message = "Destination buffer already exists",
        }
    end

    local result = core.rename(
        source,
        destination
    )

    if result.status ~= "renamed" then
        return result
    end

    local reconciled, reconcile_error =
        reconcile_buffer(
            result.source,
            result.destination
        )

    if not reconciled then
        result.buffer_error =
            tostring(reconcile_error)
    end

    return result
end

local function report_result(
    old_name,
    new_name,
    result
)
    if result.status == "renamed" then
        funcs.safe_notify(
            ("Renamed %s to %s"):format(
                old_name,
                new_name
            )
        )
        return
    end

    if result.status == "noop" then
        return
    end

    if result.status == "cancelled" then
        return
    end

    funcs.safe_notify(
        "Error renaming file: "
            .. tostring(result.message),
        vim.log.levels.ERROR
    )
end

function M.request_rename(
    directory,
    old_name,
    on_complete
)
    vim.ui.input({
        prompt = "New name for "
            .. old_name
            .. ": ",
    }, function(input)
        if input == nil or input == "" then
            local result = {
                status = "cancelled",
            }

            if on_complete then
                on_complete(result)
            end

            return
        end

        local result = M.rename_entry(
            directory,
            old_name,
            input
        )

        report_result(
            old_name,
            input,
            result
        )

        if result.status == "renamed"
            and vim.bo.filetype == "netrw"
        then
            netrw.refresh(
                directory,
                input
            )
        end

        if on_complete then
            on_complete(result)
        end
    end)
end

local function telescope_modules()
    local ok_pickers, pickers = pcall(
        require,
        "telescope.pickers"
    )
    local ok_finders, finders = pcall(
        require,
        "telescope.finders"
    )
    local ok_sorters, sorters = pcall(
        require,
        "telescope.sorters"
    )
    local ok_actions, actions = pcall(
        require,
        "telescope.actions"
    )
    local ok_state, action_state = pcall(
        require,
        "telescope.actions.state"
    )

    if not (
        ok_pickers
        and ok_finders
        and ok_sorters
        and ok_actions
        and ok_state
    ) then
        return nil
    end

    return {
        pickers = pickers,
        finders = finders,
        sorters = sorters,
        actions = actions,
        action_state = action_state,
    }
end

function M.rename_file(directory)
    directory = core.normalize_path(
        directory or vim.fn.getcwd()
    )

    if not directory then
        funcs.safe_notify(
            "Invalid directory",
            vim.log.levels.WARN
        )
        return
    end

    local telescope = telescope_modules()

    if not telescope then
        funcs.safe_notify(
            "Telescope is not installed or loaded",
            vim.log.levels.WARN
        )
        return
    end

    local files = vim.fn.readdir(directory)

    telescope.pickers.new({}, {
        prompt_title = "Rename File",
        finder = telescope.finders.new_table({
            results = files,
        }),
        sorter =
            telescope.sorters.get_generic_fuzzy_sorter(),
        attach_mappings =
            function(prompt_bufnr)
                telescope.actions.select_default:replace(
                    function()
                        local selection =
                            telescope.action_state
                                .get_selected_entry()

                        telescope.actions.close(
                            prompt_bufnr
                        )

                        if not selection
                            or not selection.value
                        then
                            return
                        end

                        M.request_rename(
                            directory,
                            selection.value
                        )
                    end
                )

                return true
            end,
    }):find()
end

function M.rename_cursor_file()
    local directory = netrw.active_directory()
    local entry = netrw.entry_under_cursor()

    if not entry then
        funcs.safe_notify(
            "No valid file under cursor",
            vim.log.levels.WARN
        )
        return
    end

    M.request_rename(
        directory,
        entry
    )
end

_G.RenameFile = M.rename_file
_G.RenameCursorFile = M.rename_cursor_file

vim.keymap.set(
    "n",
    "<leader>rn",
    function()
        M.rename_file(vim.loop.cwd())
    end,
    {
        noremap = true,
        silent = true,
    }
)

vim.keymap.set(
    "n",
    "<leader>rr",
    M.rename_cursor_file,
    {
        noremap = true,
        silent = true,
    }
)

return M
