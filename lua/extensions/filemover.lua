Filemover = Filemover or {}

Filemover.display_full_path = Filemover.display_full_path or false

local core = require("extensions.filemover.core")
local selection = require("core.netrw-selection")
local notify = require("utils.notify")
local deferred = require("utils.deferred")
local uv = vim.uv or vim.loop

local verbose = false

-- Register Filemover's mappings immediately, but only load picker internals
-- after selection/destination validation and on the first actual picker use.
local load_picker = deferred.once(function()
    if not pcall(require, "telescope") then
        notify.warning("Telescope is not installed or loaded")
        return nil
    end

    local modules = {}
    for _, dependency in ipairs({
        { "Path", "plenary.path" },
        { "pickers", "telescope.pickers" },
        { "finders", "telescope.finders" },
        { "actions", "telescope.actions" },
        { "actions_state", "telescope.actions.state" },
        { "sorters", "telescope.sorters" },
    }) do
        local key, name = dependency[1], dependency[2]
        local ok, module = pcall(require, name)
        if not ok then
            notify.warning("Filemover component unavailable: " .. name)
            return nil
        end
        modules[key] = module
    end

    return modules
end)

local function format_path(path, cwd, Path)
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

function Filemover.move_selected_files(options)
    options = options or {}
    if vim.bo.filetype ~= "netrw" then
        notify.info("Error: Operation only allowed in Netrw buffers")
        return
    end

    local selected_paths, selection_kind, selection_error =
        selection.resolve(options)
    if not selected_paths then
        notify.error("Failed to resolve netrw selection: "
            .. tostring(selection_error))
        return
    end
    if #selected_paths == 0 then
        notify.info("No netrw entries selected")
        return
    end
    local sources = core.compact_sources(selected_paths)
    local ctx = selection.capture(vim.tbl_map(function(item)
        return item.path
    end, sources))
    local cwd = core.normalize_path(uv.cwd())
    notify.debug_when(verbose,
        "Selected entries (" .. selection_kind .. "): " .. vim.inspect(sources))

    local directories = core.target_directories(cwd, sources)
    if #directories == 0 then
        notify.info("No valid target directories found in " .. cwd)
        return
    end

    local picker = load_picker()
    if not picker then
        return
    end

    picker.pickers.new({}, {
        prompt_title = "Select Target Directory",
        finder = picker.finders.new_table({
            results = directories,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry == cwd
                        and "(root)/"
                        or format_path(entry, cwd, picker.Path),
                    ordinal = entry,
                }
            end,
        }),
        sorter = picker.sorters.get_generic_fuzzy_sorter(),
        attach_mappings = function(prompt_bufnr, _)
            picker.actions.select_default:replace(function()
                local target_entry = picker.actions_state.get_selected_entry()
                picker.actions.close(prompt_bufnr)

                if not target_entry or not target_entry.value then
                    return
                end

                local target_dir = core.normalize_path(target_entry.value)
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

                if selection_kind == "marks" and moved > 0 then
                    selection.clear_marks()
                end
                if moved > 0 then
                    selection.refresh(ctx)
                end

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

vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function(args)
        vim.keymap.set("x", "<leader>fm", function()
            Filemover.move_selected_files({
                visual_rows = { vim.fn.getpos("v")[2], vim.fn.line(".") },
            })
        end, {
            buffer = args.buf,
            silent = true,
            desc = "Move visually selected netrw entries",
        })
    end,
})

return Filemover
