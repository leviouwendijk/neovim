local uv = vim.loop
local path = require("core.filetype.path")

local sensitive_extensions = {
    ".pem", ".rsa", ".env", ".key", ".crt", ".conf", ".cert", ".private", ".secret"
}

local function is_sensitive_file(full_path)
    local ext = path.extract_file_extension(full_path)
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
    local full_path, _ = path.get_path_under_cursor(line_nr)
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
    local full_path, _ = path.get_path_under_cursor(line_nr)

    local chmod = get_chmod_under_cursor(line_nr)
    if chmod then
        local human_readable = chmod_to_human(chmod)
        local is_insecure = is_sensitive_file(full_path) and not has_restricted_permission(chmod)
        local color = get_permission_color(chmod, is_insecure)

        local color_group = is_insecure and "ChmodColorInsecure" or "ChmodColor"

        vim.api.nvim_set_hl(0, color_group, { fg = color })


        local ext = path.extract_file_extension(full_path)
        local warning = is_insecure and string.format("(!) insecure permission for %s:", ext or "SENSITIVE FILE") or ""

        return { string.format(warning .. " %s %s", human_readable, chmod), color_group }
    end
    return nil
end

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

return {
    get_chmod_virtualtext = get_chmod_virtualtext,
}
