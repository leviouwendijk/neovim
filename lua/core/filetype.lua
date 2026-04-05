local uv = vim.loop

-- Settings: Define variables for behavior customization
local run_mode = "all" -- Options: "cursorline" or "all" (show for all folders or just under the cursor)
local use_gray_theme = false  -- Set to true to use grayscale instead of colored
local opacity = 0.75           -- Set opacity for colors (simulated by adjusting color intensity)
local ignore_extensions = { -- List of extensions to ignore
    ".resolved",
    ".tmp"
    }
local max_width = 50  -- Maximum width for the displayed file type percentages
local decimal_places = 0  -- Number of decimal places to round percentages to

-- Namespace for virtual text so we can manage it better
local ns_id = vim.api.nvim_create_namespace("filetype_perc")

-- Function to round a number to a specific number of decimal places
local function round(num, num_decimal_places)
    local mult = 10^(num_decimal_places or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Function to adjust opacity of a hex color (simulate opacity by reducing intensity)
local function adjust_opacity(color_hex, opacity_factor)
    local r = tonumber(color_hex:sub(2, 3), 16)
    local g = tonumber(color_hex:sub(4, 5), 16)
    local b = tonumber(color_hex:sub(6, 7), 16)

    -- Adjust each channel by the opacity factor
    r = math.floor(r * opacity_factor)
    g = math.floor(g * opacity_factor)
    b = math.floor(b * opacity_factor)

    -- Convert back to hex and return the modified color
    return string.format("#%02x%02x%02x", r, g, b)
end

-- Grayscale colors (used when use_gray_theme is true)
local gray_color_map = {
    [".lua"] = "#808080",
    [".py"] = "#888888",
    [".js"] = "#909090",
    [".html"] = "#989898",
    [".css"] = "#a0a0a0",
    [".json"] = "#a8a8a8",
    [".yaml"] = "#b0b0b0",
    [".c"] = "#b8b8b8",
    [".swift"] = "#c0c0c0",
    [".md"] = "#c8c8c8",
    [".pdf"] = "#b0b0b0",   -- Gray for PDF files
    [".sh"] = "#909090",    -- Gray for Shell scripts
    [".txt"] = "#a8a8a8",   -- Gray for Text files
}

-- Default color for unspecified extensions in gray theme
local default_gray_color = "#d0d0d0"

-- Dictionary to control appearance by file extension (RGB colors)
local ext_color_map = {
    [".lua"] = "#A3BE8C",   -- Green for Lua files
    [".py"] = "#88C0D0",    -- Blue for Python files
    [".js"] = "#EBCB8B",    -- Yellow for JavaScript files
    [".html"] = "#BF616A",  -- Red for HTML files
    [".css"] = "#8FBCBB",   -- Cyan for CSS files
    [".json"] = "#D08770",  -- Orange for JSON files
    [".yaml"] = "#B48EAD",  -- Purple for YAML files
    [".c"] = "#5E81AC",     -- Blue for C files
    [".swift"] = "#FFAC45", -- Swift files with a custom orange
    [".md"] = "#A3BE8C",    -- Markdown files green
    [".pdf"] = "#D08770",   -- Orange for PDF files
    [".sh"] = "#A3BE8C",    -- Green for Shell scripts
    [".txt"] = "#ECEFF4",   -- Light color for Text files
}

-- Default color for unspecified extensions
local default_color = "#ECEFF4"

-- Helper function to check if an extension is in the ignore list
local function is_ignored_extension(ext)
    for _, ignore_ext in ipairs(ignore_extensions) do
        if ext == ignore_ext then
            return true
        end
    end
    return false
end

-- Helper function to create a highlight group from a hex color
local function create_highlight_group(ext, color)
    local group_name = "FileTypeColor_" .. ext:gsub("%W", "") -- sanitize extension to use in group name
    vim.api.nvim_set_hl(0, group_name, { fg = color })
    return group_name
end

-- Function to count files by extension in a given directory using vim.loop
local function count_files_by_type(directory)
    local file_counts = {}
    local total_files = 0
    local handle = uv.fs_scandir(directory)

    if handle then
        while true do
            local name, file_type = uv.fs_scandir_next(handle)
            if not name then break end

            if file_type == "file" then
                local file_ext = name:match("^.+(%..+)$") -- extract file extension
                if file_ext and not is_ignored_extension(file_ext) then
                    file_counts[file_ext] = (file_counts[file_ext] or 0) + 1
                    total_files = total_files + 1
                end
            end
        end
    end

    return file_counts, total_files
end

-- Function to calculate percentages
local function calculate_percentage(file_counts, total_files)
    local percentages = {}
    for ext, count in pairs(file_counts) do
        percentages[ext] = (count / total_files) * 100
    end
    return percentages
end

-- Function to limit the width of the display string
local function trim_string_to_max_width(str, max_width)
    if #str > max_width then
        return str:sub(1, max_width - 3) .. "..." -- Truncate and add ellipsis if too long
    end
    return str
end

-- Function to get the full path of a file or directory under the cursor
local function get_path_under_cursor(line_nr)
    local line = vim.api.nvim_buf_get_lines(0, line_nr, line_nr + 1, false)[1]
    if not line then return nil end

    -- Extract the name (file or directory)
    local name = line:match("([^%s]+)$")
    if not name then return nil end

    -- Construct the full path
    local current_dir = vim.fn.expand("%:p:h")
    local full_path = current_dir .. "/" .. name

    -- Check if the path exists
    local stat = uv.fs_stat(full_path)
    if stat then
        return full_path, stat.type -- Return the path and its type ("file" or "directory")
    end

    return nil
end

-- Function to get virtual text for file types
local function get_filetype_virtualtext(directory)
    local file_counts, total_files = count_files_by_type(directory)
    if total_files == 0 then return nil end

    local percentages = calculate_percentage(file_counts, total_files)
    local virt_text = {}

    for ext, perc in pairs(percentages) do
        -- Use grayscale theme if enabled, otherwise use color theme
        local color = use_gray_theme and gray_color_map[ext] or ext_color_map[ext] or (use_gray_theme and default_gray_color or default_color)

        -- Adjust color opacity
        color = adjust_opacity(color, opacity)

        -- Create or retrieve the highlight group for this extension
        local hl_group = create_highlight_group(ext, color)

        -- Round the percentage to the specified number of decimal places
        local rounded_perc = round(perc, decimal_places)

        -- Dynamically format the percentage string based on decimal_places
        local format_string = string.format("%%s: %%.%df%%%% ", decimal_places)
        local percentage_str = string.format(format_string, ext, rounded_perc)

        -- Trim the string to max width
        percentage_str = trim_string_to_max_width(percentage_str, max_width)

        -- Add it to the virtual text array
        table.insert(virt_text, { percentage_str, hl_group })
    end

    return virt_text
end

local sensitive_extensions = {
    ".pem", ".rsa", ".env", ".key", ".crt", ".conf", ".cert", ".private", ".secret"
}

local function extract_file_extension(full_path)
    if not full_path then
        -- print("DEBUG: No full path provided.")
        return nil
    end

    local filename = full_path:match("([^/]+)$")
    if not filename then
        -- print("DEBUG: Unable to extract filename from path:", full_path)
        return nil
    end

    -- Match the file extension
    local ext = filename:match("^.+(%..+)$")
    if not ext then
        -- print("DEBUG: No extension found for file:", filename)
        return nil
    end

    return ext
end

local function is_sensitive_file(full_path)
    local ext = extract_file_extension(full_path)
    if not ext then
        -- print("DEBUG: No extension to check for sensitivity.")
        return false
    end

    -- Check if the extension is in the sensitive extensions list
    for _, sensitive_ext in ipairs(sensitive_extensions) do
        if ext == sensitive_ext then
            -- print("DEBUG: Sensitive file detected with extension:", ext)
            return true
        end
    end

    -- print("DEBUG: File is not sensitive with extension:", ext)
    return false
end

local function has_restricted_permission(chmod)
    if not chmod or #chmod < 4 then
        print("DEBUG: Invalid chmod value:", chmod) -- Debugging invalid chmod
        return false
    end

    local owner = tonumber(chmod:sub(2, 2))
    local group = tonumber(chmod:sub(3, 3))
    local others = tonumber(chmod:sub(4, 4))

    -- print(string.format("DEBUG: Chmod: %s (Owner: %d, Group: %d, Others: %d)", chmod, owner, group, others))

    -- Add warning if permissions are less restrictive than 600
    if owner < 6 or group > 0 or others > 0 then
        -- print("DEBUG: Permissions are insecure:", chmod)
        return false
    end

    -- print("DEBUG: Permissions are secure:", chmod)
    return true
end

-- Function to fetch the chmod permissions for the file or directory under the cursor
local function get_chmod_under_cursor(line_nr)
    local full_path, _ = get_path_under_cursor(line_nr)
    if not full_path then
        print("ERROR: No path found at line:", line_nr) -- Debugging missing path
        return nil
    end

    local stat = uv.fs_stat(full_path)
    if stat then
        local chmod = string.format("%o", stat.mode % 0x1000) -- Convert mode to octal
        if #chmod == 3 then
            chmod = "0" .. chmod -- Add leading zero if missing
        end
        return chmod
    end

    print("ERROR: Failed to retrieve chmod for path:", full_path) -- Debugging failed stat
    return nil
end

-- Helper function for permission styling
local function get_permission_color(chmod, is_insecure)
    if not chmod or #chmod < 4 then
        print("ERROR: Invalid chmod value:", chmod) -- Debugging invalid chmod
        return "#FFFFFF" -- Default color for invalid chmod
    end

    -- If marked as insecure, override with red color
    if is_insecure then
        -- print("DEBUG: File is insecure, applying red color") -- Debugging insecure files
        return "#BF616A" -- Red: Insecure
    end

    local owner = tonumber(chmod:sub(2, 2))
    local group = tonumber(chmod:sub(3, 3))
    local others = tonumber(chmod:sub(4, 4))

    if others > 0 then
        return "#BF616A" -- Red: Insecure (world-writable)
    elseif group >= 5 then
        return "#EBCB8B" -- Orange: Moderate (readable/executable by group)
    else
        return "#A3BE8C" -- Green: Secure (restricted to owner)
    end
end

local function secs_from_time(t)
    if not t then return nil end
    if type(t) == "number" then
        return t
    elseif type(t) == "table" then
        return t.sec or t.tv_sec or t[1]
    end
    return nil
end

local function get_file_dates(full_path)
    if not full_path then return nil end
    local stat = uv.fs_stat(full_path)
    if not stat then return nil end

    -- libuv / luv may expose birthtime / ctime / mtime as numbers or tables
    local created_secs = secs_from_time(stat.birthtime) or secs_from_time(stat.ctime)
    local modified_secs = secs_from_time(stat.mtime)

    local created_str = created_secs and os.date("%Y-%m-%d %H:%M", created_secs) or nil
    local modified_str = modified_secs and os.date("%Y-%m-%d %H:%M", modified_secs) or nil

    return created_str, modified_str
end

-- Helper function for permission styling
local function chmod_to_human(chmod)
    if not chmod or #chmod < 4 then
        print("ERROR: Invalid chmod value:", chmod) -- Debugging invalid chmod
        return "O:--- G:--- U:---" -- Default invalid representation
    end

    local modes = {
        [0] = "---",
        [1] = "--x",
        [2] = "-w-",
        [3] = "-wx",
        [4] = "r--",
        [5] = "r-x",
        [6] = "rw-",
        [7] = "rwx",
    }

    -- Explicitly label each group
    local owner = modes[tonumber(chmod:sub(2, 2))]
    local group = modes[tonumber(chmod:sub(3, 3))]
    local others = modes[tonumber(chmod:sub(4, 4))]

    return string.format("%s %s %s", owner, group, others)
end

-- Function to get virtual text for chmod
local function get_chmod_virtualtext(line_nr)
    local full_path, _ = get_path_under_cursor(line_nr)

    local chmod = get_chmod_under_cursor(line_nr)
    if chmod then
        local human_readable = chmod_to_human(chmod)
        local is_insecure = is_sensitive_file(full_path) and not has_restricted_permission(chmod)
        local color = get_permission_color(chmod, is_insecure)

        local color_group = is_insecure and "ChmodColorInsecure" or "ChmodColor"

        vim.api.nvim_set_hl(0, color_group, { fg = color })


        local ext = extract_file_extension(full_path)
        local warning = is_insecure and string.format("(!) insecure permission for %s:", ext or "SENSITIVE FILE") or ""

        return { string.format(warning .. " %s %s", human_readable, chmod), color_group }
    end
    return nil
end

-- Function to orchestrate cursorline virtual text display
local function display_cursorline_virtualtext(_, line_nr)
    -- Clear previous virtual text from this line
    vim.api.nvim_buf_clear_namespace(0, ns_id, line_nr, line_nr + 1)

    local virt_text = {}

    -- Fetch filetype percentages if a directory
    local full_path, path_type = get_path_under_cursor(line_nr)
    if path_type == "directory" then
        local filetype_text = get_filetype_virtualtext(full_path)
        if filetype_text then
            for _, item in ipairs(filetype_text) do
                table.insert(virt_text, item)
            end
        end

    -- NEW:
    elseif path_type == "file" then
        local created, _ = get_file_dates(full_path)
        -- local created, modified = get_file_dates(full_path)
        if created then
            local ext = extract_file_extension(full_path)
            local color = use_gray_theme and (gray_color_map[ext] or default_gray_color) or (ext_color_map[ext] or default_color)
            color = adjust_opacity(color, opacity)

            local created_color = adjust_opacity(color, opacity)
            local modified_color = adjust_opacity(color, math.max(0, opacity * 0.85))

            vim.api.nvim_set_hl(0, "FileDateCreated", { fg = created_color })
            vim.api.nvim_set_hl(0, "FileDateModified", { fg = modified_color })

--             if modified then
--                 table.insert(virt_text, { string.format("%s[+] ", modified), "FileDateModified" })
--             end

            -- table.insert(virt_text, { string.format("%s[=] ", created), "FileDateCreated" })
            table.insert(virt_text, { string.format("%s ", created), "FileDateCreated" })
        end
    end

    -- Fetch chmod for the cursorline
    local chmod_text = get_chmod_virtualtext(line_nr)
    if chmod_text then
        table.insert(virt_text, chmod_text)
    end

    -- Set virtual text aligned to the right
    vim.api.nvim_buf_set_extmark(0, ns_id, line_nr, 0, {
        virt_text = virt_text,
        virt_text_pos = "right_align"
    })
end

-- -- Function to get the directory on the given line (instead of the cursor)
-- [REPLACED: integrated chmod value, required checking file paths also (not just directories for filetypes)
-- local function get_directory_on_line(line_nr)
--     local line = vim.api.nvim_buf_get_lines(0, line_nr, line_nr + 1, false)[1]
--     if not line then return nil end

--     -- Extract directory name (assuming netrw format, adjust if necessary)
--     local dir_name = line:match("([^%s]+)$")
--     if dir_name then
--         -- Check if it's a valid directory
--         local current_dir = vim.fn.expand("%:p:h")
--         local full_path = current_dir .. "/" .. dir_name
--         if uv.fs_stat(full_path) and uv.fs_stat(full_path).type == "directory" then
--             return full_path
--         end
--     end
--     return nil
-- end

-- Autocommand to trigger on cursor movement in netrw explorer
vim.api.nvim_create_autocmd("CursorMoved", {
    pattern = "*",
    callback = function()
        if vim.bo.filetype == "netrw" then
            if run_mode == "cursorline" then
                -- Get the file or directory under the cursor
                local path, _ = get_path_under_cursor(vim.api.nvim_win_get_cursor(0)[1] - 1) -- Lua is 1-indexed
                if path then
                    -- Display virtual text for the cursorline
                    display_cursorline_virtualtext(path, vim.api.nvim_win_get_cursor(0)[1] - 1)
                end
            elseif run_mode == "all" then
                -- For all items (files and directories) visible in the explorer window
                local line_count = vim.api.nvim_buf_line_count(0)
                for i = 0, line_count - 1 do
                    local path, _ = get_path_under_cursor(i)
                    if path then
                        display_cursorline_virtualtext(path, i)
                    end
                end
            end
        end
    end,
})


-- ABOUT CHMOD PERMISSIONS (INDEX):
-- 
-- Each permission digit (0-7) represents:
--   r: Read
--   w: Write
--   x: Execute
--   -: No permission
-- 
-- Octal to Human Readable Conversion:
--   0: ---  (No permissions)
--   1: --x  (Execute only)
--   2: -w-  (Write only)
--   3: -wx  (Write and execute)
--   4: r--  (Read only)
--   5: r-x  (Read and execute)
--   6: rw-  (Read and write)
--   7: rwx  (Read, write, and execute)
-- 
-- Combined Permissions:
-- Permissions are applied in three groups: owner, group, and others.
-- For example:
--   rwxr-xr-x (755) means:
--     - Owner: rwx  (Read, write, execute)
--     - Group: r-x  (Read, execute)
--     - Others: r-x (Read, execute)
-- 
-- Special Permission Bits (Optional first digit in chmod):
--   1: Sticky bit  - Prevents users from deleting files they don't own in shared directories.
--   2: Setgid      - Executes with the group ID of the file, not the executing user.
--   4: Setuid      - Executes with the user ID of the file, not the executing user.
-- Examples of special permissions:
--   1755: Sticky bit + rwxr-xr-x
--   2755: Setgid + rwxr-xr-x
--   4755: Setuid + rwxr-xr-x
-- 
-- Common Examples:
--   0644: rw-r--r--  (Owner can read and write; group and others can only read)
--   0755: rwxr-xr-x  (Owner can read, write, and execute; group and others can read and execute)
--   0777: rwxrwxrwx  (Everyone can read, write, and execute — generally insecure)
--   0700: rwx------  (Only the owner can read, write, and execute)
--   0711: rwx--x--x  (Owner can read, write, and execute; group and others can only execute)

-- File Permission Pointers:
-- Proper file permissions are critical for security. Misconfigured permissions can lead to data leaks or unauthorized access.
-- 
-- General Best Practices:
--   - Restrict permissions for sensitive files to the owner only:
--     - .env files: `chmod 600` (rw-------)
--     - Private keys: `chmod 600` or stricter (rw-------)
--     - Configuration files (e.g., nginx.conf, db.conf): `chmod 640` (rw-r-----)
--     - Scripts that must not be executed by others: `chmod 600` (rw-------)
-- 
-- Examples of Common Permissions:
--   - Directories:
--       - Public directories (e.g., /var/www/html): `chmod 755` (rwxr-xr-x)
--       - Private directories: `chmod 700` (rwx------)
--   - Executable scripts:
--       - Scripts shared among users: `chmod 750` (rwxr-x---)
--       - Personal scripts: `chmod 700` (rwx------)
--   - Log files:
--       - General logs: `chmod 640` (rw-r-----)
--       - Sensitive logs: `chmod 600` (rw-------)
-- 
-- Special Notes on `.env` Files:
--   - `.env` files typically contain sensitive environment variables such as:
--       - API keys
--       - Database credentials
--       - Encryption keys
--   - Permissions should be set to `600`:
--       - rw------- (Readable and writable by the owner only)
--       - Prevent group and others from accessing these files to avoid accidental exposure or leaks.
-- 
-- Additional Recommendations:
--   - Always check permissions with `ls -l`.
--   - Use `chmod` carefully to avoid inadvertently increasing access (e.g., `chmod 777` is highly discouraged).
--   - For shared servers or multi-user environments, ensure `umask` is set to restrict default permissions (e.g., `umask 027`).
-- 
-- Example Commands:
--   chmod 600 .env      # Secure a .env file
--   chmod 700 private/  # Restrict access to a private directory
--   chmod 644 public.txt # Make a file publicly readable
-- ```

