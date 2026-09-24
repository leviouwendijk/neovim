local uv = vim.loop

local function current_directory()
    if
        vim.bo.filetype == "netrw"
        and vim.b.netrw_curdir
        and vim.b.netrw_curdir ~= ""
    then
        return vim.fs.normalize(vim.b.netrw_curdir)
    end

    local buffer_name = vim.api.nvim_buf_get_name(0)
    local stat =
        buffer_name ~= ""
        and uv.fs_stat(buffer_name)
        or nil

    if stat and stat.type == "directory" then
        return vim.fs.normalize(buffer_name)
    end

    return vim.fs.normalize(
        vim.fn.expand("%:p:h")
    )
end

local function resolve_entry(directory, name)
    if
        not directory
        or directory == ""
        or not name
        or name == ""
    then
        return nil
    end

    local full_path =
        vim.fs.normalize(
            directory .. "/" .. name
        )

    local stat = uv.fs_stat(full_path)
    if not stat then
        return nil
    end

    return full_path, stat.type
end

-- Function to get the full path of a file or directory under the cursor
local function get_entry_under_cursor(line_nr)
    local line =
        vim.api.nvim_buf_get_lines(
            0,
            line_nr,
            line_nr + 1,
            false
        )[1]

    if not line then return nil end

    -- Extract the name (file or directory)
    local name = line:match("([^%s]+)$")
    if not name then return nil end

    -- Construct the full path
    local full_path, path_type =
        resolve_entry(
            current_directory(),
            name
        )

    -- Check if the path exists
    if full_path then
        return {
            name = name,
            path = full_path,
            type = path_type,
        }
    end

    return nil
end

local function get_path_under_cursor(line_nr)
    local entry = get_entry_under_cursor(line_nr)
    if not entry then
        return nil
    end

    return entry.path, entry.type -- Return the path and its type ("file" or "directory")
end

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

return {
    current_directory = current_directory,
    resolve_entry = resolve_entry,
    get_entry_under_cursor = get_entry_under_cursor,
    get_path_under_cursor = get_path_under_cursor,
    extract_file_extension = extract_file_extension,
    get_file_dates = get_file_dates,
}
