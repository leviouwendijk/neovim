local path = require("core.filetype.path")
local stats = require("core.filetype.stats")
local permissions = require("core.filetype.permissions")
local layout = require("core.filetype.layout")

-- Settings: Define variables for behavior customization
local run_mode = "all" -- Options: "cursorline" or "all" (show for all folders or just under the cursor)

-- Namespace for virtual text so we can manage it better
local ns_id = vim.api.nvim_create_namespace("filetype_perc")

local function add_chunk(chunks, item, priority, group)
    if not item then
        return
    end

    table.insert(chunks, {
        text = item[1],
        highlight = item[2],
        priority = priority,
        group = group,
    })
end

-- Function to orchestrate cursorline virtual text display
local function display_cursorline_virtualtext(_, line_nr)
    -- Clear previous virtual text from this line
    vim.api.nvim_buf_clear_namespace(
        0,
        ns_id,
        line_nr,
        line_nr + 1
    )

    local chunks = {}

    -- Fetch filetype percentages if a directory
    local full_path, path_type =
        path.get_path_under_cursor(line_nr)

    if path_type == "directory" then
        local filetype_text =
            stats.get_filetype_virtualtext(full_path)

        if filetype_text then
            for _, item in ipairs(filetype_text) do
                add_chunk(
                    chunks,
                    item,
                    layout.priority.stats,
                    "stats"
                )
            end
        end

    -- NEW:
    elseif path_type == "file" then
        local created, _ =
            path.get_file_dates(full_path)
        -- local created, modified = get_file_dates(full_path)
        if created then
            local ext =
                path.extract_file_extension(full_path)
            local color =
                stats.use_gray_theme
                and (
                    stats.gray_color_map[ext]
                    or stats.default_gray_color
                )
                or (
                    stats.ext_color_map[ext]
                    or stats.default_color
                )

            color =
                stats.adjust_opacity(
                    color,
                    stats.opacity
                )

            local created_color =
                stats.adjust_opacity(
                    color,
                    stats.opacity
                )
            local modified_color =
                stats.adjust_opacity(
                    color,
                    math.max(
                        0,
                        stats.opacity * 0.85
                    )
                )

            vim.api.nvim_set_hl(
                0,
                "FileDateCreated",
                {
                    fg = created_color,
                }
            )
            vim.api.nvim_set_hl(
                0,
                "FileDateModified",
                {
                    fg = modified_color,
                }
            )

--             if modified then
--                 table.insert(virt_text, { string.format("%s[+] ", modified), "FileDateModified" })
--             end

            -- table.insert(virt_text, { string.format("%s[=] ", created), "FileDateCreated" })
            add_chunk(
                chunks,
                {
                    string.format(
                        "%s ",
                        created
                    ),
                    "FileDateCreated",
                },
                layout.priority.date
            )
        end
    end

    -- Fetch chmod for the cursorline
    local chmod_text =
        permissions.get_chmod_virtualtext(line_nr)

    if chmod_text then
        local priority =
            chmod_text[2] == "ChmodColorInsecure"
            and layout.priority.warning
            or layout.priority.permission

        add_chunk(
            chunks,
            chmod_text,
            priority
        )
    end

    local line =
        vim.api.nvim_buf_get_lines(
            0,
            line_nr,
            line_nr + 1,
            false
        )[1]
        or ""

    local budget =
        layout.window_budget(
            vim.api.nvim_get_current_win(),
            line
        )
    local virt_text =
        layout.fit(chunks, budget)

    -- Set virtual text aligned to the right
    if #virt_text > 0 then
        vim.api.nvim_buf_set_extmark(
            0,
            ns_id,
            line_nr,
            0,
            {
                virt_text = virt_text,
                virt_text_pos = "right_align",
            }
        )
    end
end

local function refresh_current_window()
    if vim.bo.filetype ~= "netrw" then
        return
    end

    if run_mode == "cursorline" then
        -- Get the file or directory under the cursor
        local full_path, _ =
            path.get_path_under_cursor(
                vim.api.nvim_win_get_cursor(0)[1] - 1
            ) -- Lua is 1-indexed

        if full_path then
            -- Display virtual text for the cursorline
            display_cursorline_virtualtext(
                full_path,
                vim.api.nvim_win_get_cursor(0)[1] - 1
            )
        end
    elseif run_mode == "all" then
        -- For all items (files and directories) visible in the explorer window
        local line_count =
            vim.api.nvim_buf_line_count(0)

        for i = 0, line_count - 1 do
            local full_path, _ =
                path.get_path_under_cursor(i)

            if full_path then
                display_cursorline_virtualtext(
                    full_path,
                    i
                )
            end
        end
    end
end

-- Autocommand to trigger on cursor movement in netrw explorer
vim.api.nvim_create_autocmd(
    "CursorMoved",
    {
        pattern = "*",
        callback = refresh_current_window,
    }
)

-- Recalculate right-aligned metadata when window geometry changes.
vim.api.nvim_create_autocmd(
    {
        "WinResized",
        "VimResized",
    },
    {
        callback = function()
            for _, win in ipairs(
                vim.api.nvim_list_wins()
            ) do
                if
                    vim.api.nvim_win_is_valid(win)
                    and vim.bo[
                        vim.api.nvim_win_get_buf(win)
                    ].filetype == "netrw"
                then
                    vim.api.nvim_win_call(
                        win,
                        refresh_current_window
                    )
                end
            end
        end,
    }
)
