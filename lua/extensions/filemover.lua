Filemover = Filemover or {}

Filemover.display_full_path = Filemover.display_full_path or false

local Path = require("plenary.path")
local core = require("extensions.filemover.core")
local netrw = require("extensions.filemover.netrw")
local notify = require("utils.notify")
local uv = vim.uv or vim.loop

local verbose = false

if not pcall(require, "telescope") then
    notify.warning("Telescope is not installed or loaded")
    return Filemover
end

local ok_pickers, pickers = pcall(require, "telescope.pickers")
local ok_finders, finders = pcall(require, "telescope.finders")
local ok_actions, actions = pcall(require, "telescope.actions")
local ok_actions_state, actions_state = pcall(
    require,
    "telescope.actions.state"
)
local ok_sorters, sorters = pcall(require, "telescope.sorters")

if not (
    ok_pickers
    and ok_finders
    and ok_actions
    and ok_actions_state
    and ok_sorters
) then
    notify.warning("Telescope or one of its components is not available")
    return Filemover
end

local function format_path(path, cwd)
    if Filemover.display_full_path then
        return path
    end

    return Path:new(path):make_relative(cwd)
end

local function reconcile_buffers(result)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr)
            and vim.bo[bufnr].buftype == ""
            and vim.bo[bufnr].filetype ~= "netrw"
        then
            local name = vim.api.nvim_buf_get_name(bufnr)

            if name ~= "" then
                local buffer_path = core.normalize_path(name)
                local affected =
                    buffer_path == result.source
                    or (
                        result.kind == "directory"
                        and core.path_is_within(
                            buffer_path,
                            result.source
                        )
                    )

                if affected then
                    local suffix = buffer_path:sub(#result.source + 1)
                    local ok, err = pcall(
                        vim.api.nvim_buf_set_name,
                        bufnr,
                        result.destination .. suffix
                    )

                    if not ok then
                        notify.warning(
                            "Moved on disk but failed to update buffer name: "
                                .. tostring(err)
                        )
                    end
                end
            end
        end
    end
end

function Filemover.move_selected_files()
    if vim.bo.filetype ~= "netrw" then
        notify.info("Error: Operation only allowed in Netrw buffers")
        return
    end

    local ctx = {
        win = vim.api.nvim_get_current_win(),
        dir = netrw.active_directory(),
        cursor = vim.api.nvim_win_get_cursor(0),
    }

    local cwd = core.normalize_path(uv.cwd())
    local marked_paths, mark_error = netrw.marked_paths()

    if not marked_paths then
        notify.error("Failed to read Netrw marks: " .. mark_error)
        return
    end

    if #marked_paths == 0 then
        notify.info("No files are marked in Netrw")
        return
    end

    local sources = core.compact_sources(marked_paths)
    notify.debug_when(
        verbose,
        "Marked entries: " .. vim.inspect(sources)
    )

    local directories = core.target_directories(cwd, sources)
    if #directories == 0 then
        notify.info("No valid target directories found in " .. cwd)
        return
    end

    pickers.new({}, {
        prompt_title = "Select Target Directory",
        finder = finders.new_table({
            results = directories,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry == cwd
                        and "(root)/"
                        or format_path(entry, cwd),
                    ordinal = entry,
                }
            end,
        }),
        sorter = sorters.get_generic_fuzzy_sorter(),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local selection = actions_state.get_selected_entry()
                actions.close(prompt_bufnr)

                if not selection or not selection.value then
                    return
                end

                local target_dir = core.normalize_path(selection.value)
                local moved = 0
                local skipped = 0
                local failed = 0

                for _, source in ipairs(sources) do
                    local result = core.move_entry(
                        source,
                        target_dir
                    )

                    if result.status == "moved" then
                        reconcile_buffers(result)
                        moved = moved + 1

                        notify.info(
                            "Moved: "
                                .. result.source
                                .. " -> "
                                .. result.destination
                        )
                    elseif result.status == "noop" then
                        skipped = skipped + 1
                    else
                        failed = failed + 1

                        notify.error(
                            "Move failed for "
                                .. result.source
                                .. ": "
                                .. result.message
                        )
                    end
                end

                netrw.clear_marks()
                netrw.refresh(ctx)

                notify.debug_when(
                    verbose,
                    string.format(
                        "Move batch complete: %d moved, %d skipped, %d failed",
                        moved,
                        skipped,
                        failed
                    )
                )
            end)

            return true
        end,
    }):find()
end

vim.api.nvim_set_keymap(
    "n",
    "<leader>tp",
    ":lua Filemover.display_full_path = not Filemover.display_full_path; require('utils.notify').info('Display Full Path: ' .. tostring(Filemover.display_full_path))<CR>",
    { noremap = true, silent = true }
)

vim.api.nvim_set_keymap(
    "n",
    "<leader>fm",
    ":lua Filemover.move_selected_files()<CR>",
    { noremap = true, silent = true }
)

vim.api.nvim_create_user_command(
    "MoveFiles",
    Filemover.move_selected_files,
    {}
)

return Filemover
