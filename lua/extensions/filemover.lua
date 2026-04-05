Filemover = {}

Filemover.display_full_path = Filemover.display_full_path or false

Filemover.last_directories = {}
Filemover.current_directory_index = nil

local MAX_HISTORY = 5

local function add_to_directory_history(dir)
    if #Filemover.last_directories >= MAX_HISTORY then
        table.remove(Filemover.last_directories, 1)
    end
    table.insert(Filemover.last_directories, dir)
    Filemover.current_directory_index = #Filemover.last_directories
end

local Path = require("plenary.path")
-- local telescope_ok, telescope = pcall(require, "telescope")
local telescope_ok = pcall(require, "telescope")
local notify = require("utils.notify")

local verbose = false

if not telescope_ok then
    local ok_notify, _ = pcall(require, "utils.notify")
    if ok_notify and vim.notify then
        vim.notify("Telescope is not installed or loaded", vim.log.levels.WARN)
    else
        print("Telescope is not installed or loaded")
    end
    return
end

local ok_pickers, pickers = pcall(require, "telescope.pickers")
local ok_finders, finders = pcall(require, "telescope.finders")
local ok_actions, actions = pcall(require, "telescope.actions")
local ok_actions_state, actions_state = pcall(require, "telescope.actions.state")
local ok_sorters, sorters = pcall(require, "telescope.sorters")
-- local ok_previewers, previewers = pcall(require, "telescope.previewers")
local ok_previewers = pcall(require, "telescope.previewers")

if not (ok_pickers and ok_finders and ok_actions and ok_actions_state and ok_sorters and ok_previewers) then
    notify.warning("Telescope or one of its components is not available")
    return
end

local function format_path(path, cwd)
    if Filemover.display_full_path then
        return path
    else
        return Path:new(path):make_relative(cwd)
    end
end

local function list_directories(dir)
    local dirs = {}
    local handle = vim.loop.fs_scandir(dir)
    if not handle then return dirs end

    while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        local full_path = dir .. "/" .. name

        if type == "directory" then
            table.insert(dirs, full_path)
            local sub_dirs = list_directories(full_path)
            for _, sub_dir in ipairs(sub_dirs) do
                table.insert(dirs, sub_dir)
            end
        end
    end
    return dirs
end

-- local function ensure_netrw_buffer(dir)
--     local buf = vim.api.nvim_get_current_buf()
--     if vim.bo[buf].filetype ~= "netrw" then
--         vim.cmd("silent keepalt keepjumps edit " .. vim.fn.fnameescape(dir))
--         notify.debug_when(verbose, "Opened netrw for: " .. dir)
--     end
-- end

-- local function refresh_netrw(dir)
--     if vim.bo.filetype == "netrw" then
--         vim.cmd("silent keepalt keepjumps edit " .. vim.fn.fnameescape(dir))
--     end
--     ensure_netrw_buffer(dir)
--     add_to_directory_history(dir)
--     notify.debug_when(verbose, "Netrw view refreshed for: " .. dir)
-- end

-- new additions to stay in netrw:
local function get_active_netrw_dir()
    if vim.bo.filetype == "netrw" and vim.b.netrw_curdir and vim.b.netrw_curdir ~= "" then
        return vim.b.netrw_curdir
    end
    -- Fallbacks if we weren’t actually in netrw when called
    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" and vim.fn.isdirectory(name) == 1 then return name end
    return vim.fn.getcwd()
end

local function reopen_netrw(dir)
    vim.cmd("silent keepalt keepjumps edit " .. vim.fn.fnameescape(dir))
end

-- refresh the *same* netrw buffer/window where we started
local function refresh_same_netrw(ctx)
    if ctx.win and vim.api.nvim_win_is_valid(ctx.win) then
        vim.api.nvim_set_current_win(ctx.win)
    end
    if ctx.dir then
        reopen_netrw(ctx.dir)
    end
    if ctx.cursor then
        pcall(vim.api.nvim_win_set_cursor, 0, ctx.cursor)
    end
end

local function ensure_netrw_buffer(dir)
    if vim.bo.filetype ~= "netrw" or not vim.b.netrw_curdir or vim.b.netrw_curdir ~= dir then
        reopen_netrw(dir)
        notify.debug_when(verbose, "Opened netrw for: " .. dir)
    end
end

-- local function refresh_netrw(dir)
--     if vim.bo.filetype == "netrw" then
--         reopen_netrw(dir)
--     else
--         ensure_netrw_buffer(dir)
--     end
--     add_to_directory_history(dir)
--     notify.debug_when(verbose, "Netrw view refreshed for: " .. dir)
-- end

-- local function refresh_netrw(dir)
--     if vim.bo.filetype == "netrw" then
--         reopen_netrw(dir)
--     else
--         ensure_netrw_buffer(dir)
--     end
--     add_to_directory_history(dir)
--     notify.debug_when(verbose, "Netrw view refreshed for: " .. dir)
-- end

local function evacuate_windows_from_buffer(bufnr, replacement_dir)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
            vim.api.nvim_set_current_win(win)
            ensure_netrw_buffer(replacement_dir)
        end
    end
end


local function perform_file_move(source_path, target_dir, cwd)
    local target_path = target_dir .. "/" .. vim.fn.fnamemodify(source_path, ":t")
    notify.debug_when(verbose, "Attempting to move: " .. source_path .. " -> " .. target_path)

    if source_path == target_path then
        notify.info("Skipping move: Source and target paths are identical.")
        return
    end
    if not vim.loop.fs_stat(source_path) then
        notify.info("Source file missing before move: " .. source_path)
        return
    end

    local full = vim.fn.fnamemodify(source_path, ":p")
    local bufnr = vim.fn.bufnr(full)
    if bufnr ~= -1 then
        evacuate_windows_from_buffer(bufnr, cwd)
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    vim.fn.mkdir(target_dir, "p")
    local ok, err = os.rename(source_path, target_path)
    if not ok then
        notify.error("Error moving " .. source_path .. ": " .. err)
        return
    end

    notify.info("Moved successfully: " .. source_path .. " -> " .. target_path)
end

function Filemover.move_selected_files()
    if vim.bo.filetype ~= "netrw" then
        notify.info("Error: Operation only allowed in Netrw buffers")
        return
    end

    -- capture context so we can return to *this* explorer
    local ctx = {
      win = vim.api.nvim_get_current_win(),
      buf = vim.api.nvim_get_current_buf(),
      dir = get_active_netrw_dir(),
      cursor = vim.api.nvim_win_get_cursor(0),
    }

    -- maintain a reference to the nvim cwd entry point ( for root, and telescope view )
    local cwd = vim.loop.cwd()
    notify.debug_when(verbose, "Current working directory: " .. cwd)

    -- ensure we also track netrw's cwd for staying in that buffer after we perform the filemove
    local netrw_cwd = ctx.dir  -- USE EXISTING NETRW
    notify.debug_when(verbose, "Netrw directory: " .. netrw_cwd)

    local success, marked_files = pcall(vim.fn["netrw#Expose"], "netrwmarkfilelist")
    if not success or #marked_files == 0 then
        notify.info("No files are marked in Netrw")
        return
    end

    notify.debug_when(verbose, "Marked Files: " .. vim.inspect(marked_files))

    local directories = list_directories(cwd)
    table.insert(directories, 1, cwd)

    -- check with above line now always evals to false
    if #directories == 0 then
        notify.info("No directories found in " .. cwd)
        return
    end

    pickers.new({}, {
        prompt_title = "Select Target Directory",
        finder = finders.new_table {
            results = directories,
            entry_maker = function(entry)
                return {
                    value = entry,
                    -- display = format_path(entry, cwd),
                    display = (entry == cwd) and "(root)/" or format_path(entry, cwd),
                    -- adding root support, with fallback to non-root dirs
                    ordinal = entry,
                }
            end,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        -- attach_mappings = function(prompt_bufnr, map)
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local selection = actions_state.get_selected_entry()
                actions.close(prompt_bufnr)

                local target_dir = selection.value
                notify.debug_when(verbose, "Selected directory: " .. target_dir)

                for _, source_path in ipairs(marked_files) do
                    perform_file_move(source_path, target_dir, cwd)
                end
                if vim.bo.filetype == "netrw" then
                    vim.cmd("silent! normal! mu")
                end
                -- refresh_netrw(cwd)
                refresh_same_netrw(ctx)
                notify.debug_when(verbose, "Netrw view fully refreshed")
            end)
            return true
        end,
    }):find()
end

vim.api.nvim_set_keymap(
    "n",
    "<leader>tp",
    -- ":lua Filemover.display_full_path = not Filemover.display_full_path; print('Display Full Path: ' .. tostring(Filemover.display_full_path))<CR>",
    ":lua Filemover.display_full_path = not Filemover.display_full_path; require('utils.notify').info('Display Full Path: ' .. tostring(Filemover.display_full_path))<CR>",
    { noremap = true, silent = true }
)

vim.api.nvim_set_keymap("n", "<leader>fm", ":lua Filemover.move_selected_files()<CR>", { noremap = true, silent = true })

vim.api.nvim_create_user_command("MoveFiles", Filemover.move_selected_files, {})

-- -- Experimental (breaking change): navigating across moved directories
-- -- Helper function to navigate to a directory in the history
-- function Filemover.navigate_directory_history(backward)
--     if not Filemover.last_directories or #Filemover.last_directories == 0 then
--         print("No directory history available.")
--         return
--     end

--     if backward then
--         Filemover.current_directory_index = (Filemover.current_directory_index - 2 + #Filemover.last_directories) % #Filemover.last_directories + 1
--     else
--         Filemover.current_directory_index = (Filemover.current_directory_index % #Filemover.last_directories) + 1
--     end

--     local target_dir = Filemover.last_directories[Filemover.current_directory_index]
--     print("Navigating to directory: " .. target_dir)
--     vim.cmd("lcd " .. target_dir)
--     vim.cmd("Rex") -- Reload Netrw
-- end

-- -- Key mapping to navigate directory history
-- vim.api.nvim_set_keymap("n", "<leader>fh", ":lua navigate_directory_history(true)<CR>", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("n", "<leader>fl", ":lua navigate_directory_history(false)<CR>", { noremap = true, silent = true })
