function SearchFile(directory, filename)
    print("Searching in directory: " .. directory)  -- Debug: show current directory
    local files = vim.fn.readdir(directory)
    if not files or #files == 0 then
        print("Error: Unable to read directory or directory empty: " .. directory)
        return nil
    end

    for _, entry in ipairs(files) do
        local fullpath = directory .. '/' .. entry
        local is_directory = vim.fn.isdirectory(fullpath)
        print("Examining: " .. entry .. " at " .. fullpath)  -- Debug: show each file path being examined
        if is_directory == 1 and entry ~= '.' and entry ~= '..' then
            print("Entering directory: " .. fullpath)  -- Debug: entering a sub-directory
            local result = SearchFile(fullpath, filename)
            if result then
                print("Found file in sub-directory: " .. result)  -- Debug: successful find in a sub-directory
                return result
            end
        elseif is_directory == 0 and entry == filename then
            print("File found: " .. fullpath)  -- Debug: file found
            return fullpath
        end
    end
    print("File not found in: " .. directory)  -- Debug: file not found in current directory
    return nil
end


function refreshStorageFile()
    local home = os.getenv("HOME")
    local storage_filename = home .. "/myworkdir/.uuid-index"
    local storage_file = io.open(storage_filename, 'r')
    if not storage_file then
        print("Error: Unable to open storage file for reading")
        return
    end

    local filepath_to_uuid = {}
    local lines_to_keep = {}

    -- First, build a map of the latest UUID for each filepath
    for line in storage_file:lines() do
        local uuid, full_filepath = line:match("(%S+)%s+(.+)")
        if full_filepath and not full_filepath:match("# File not found") then
            local normalized_path = vim.fn.fnamemodify(full_filepath, ':p')
            -- Store the most recent valid UUID for each path
            filepath_to_uuid[normalized_path] = uuid
        end
    end
    storage_file:close()

    -- Reopen the file to determine which lines to keep
    storage_file = io.open(storage_filename, 'r')
    for line in storage_file:lines() do
        local uuid, full_filepath = line:match("(%S+)%s+(.+)")
        if full_filepath then
            local normalized_path = vim.fn.fnamemodify(full_filepath, ':p')
            if filepath_to_uuid[normalized_path] == uuid or full_filepath:match("# File not found") then
                -- Keep this line only if it matches the latest UUID or is marked as not found
                lines_to_keep[#lines_to_keep + 1] = line
            end
        end
    end
    storage_file:close()

    -- Rewrite the file with only the valid or latest entries
    storage_file = io.open(storage_filename, 'w')
    for _, line in ipairs(lines_to_keep) do
        storage_file:write(line .. '\n')
    end
    storage_file:close()

    print('Storage file updated with deduplicated UUIDs')
end

function SaveUUIDToFile(uuid, filename, filepath)
    local home = os.getenv("HOME")
    local storage_filename = home .. "/myworkdir/.uuid-index" 
    local storage_file = io.open(storage_filename, 'a')

    local full_filepath = vim.fn.fnamemodify(filepath, ':p')  -- Normalize to an absolute path

    storage_file:write(string.format("%s %s %s\n", uuid, filename, full_filepath))

    storage_file:close()
end


function getUUIDForFile(filename, filepath)
    local home = os.getenv("HOME")
    local storage_filename = home .. "/myworkdir/.uuid-index"
    local storage_file = io.open(storage_filename, 'r')
    local normalized_filepath = vim.fn.fnamemodify(filepath, ':p')  -- Ensure filepath is normalized

    if not storage_file then
        print("Unable to open storage file: " .. storage_filename)
        return nil
    end

    -- Read through each line, properly parsing out fields
    local pattern = '(%S+)%s+(%S+)%s+(.+)'  -- UUID, filename, filepath
    for line in storage_file:lines() do
        local uuid, stored_filename, stored_filepath = line:match(pattern)
        local normalized_stored_filepath = vim.fn.fnamemodify(stored_filepath, ':p')
        if stored_filename == filename and normalized_stored_filepath == normalized_filepath then
            storage_file:close()
            return uuid
        end
    end

    storage_file:close()
    return nil
end


function generateUUID(filename, filepath)
    local existing_uuid = getUUIDForFile(filename, filepath)
    print("Existing UUID check: ", existing_uuid)  -- Debugging line to check what UUID is found
    if existing_uuid then
        print("Using existing UUID: " .. existing_uuid)  -- Confirming use of existing UUID
        return existing_uuid
    end

    -- If no existing UUID, generate a new one
    local handle = io.popen('uuidgen')
    local uuid = handle:read('*a')
    handle:close()
    uuid = uuid:gsub('^%s*(.-)%s*$', '%1')  -- Trim any excess whitespace

    SaveUUIDToFile(uuid, filename, filepath)
    print("Generated new UUID: " .. uuid)  -- Confirming new UUID generation
    return uuid
end

function copyToClipboard(text)
    local temp_file = io.open(os.getenv("HOME") .. "/.temp_uuid.txt", "w")
    if not temp_file then
        print("Error: Unable to open temporary file")
        return
    end
    temp_file:write(text)
    temp_file:close()
    os.execute("cat " .. os.getenv("HOME") .. "/.temp_uuid.txt | pbcopy")
    os.remove(os.getenv("HOME") .. "/.temp_uuid.txt")
end


function callUUID()
    local filename = vim.fn.expand('%:t')
    local filepath = vim.fn.expand('%:p')
    print("Filename: " .. filename)  -- Debug: Check filename
    print("Filepath: " .. filepath)  -- Debug: Check filepath

    local existing_uuid = getUUIDForFile(filename, filepath)
    print("Existing UUID: " .. (existing_uuid or "None"))  -- Debug: Display existing UUID or None

    if existing_uuid then
        print("UUID already exists, copying to clipboard.")  -- Debug: Inform about existing UUID
        copyToClipboard(existing_uuid)
    else
        print("No UUID found, generating new.")  -- Debug: Inform about new UUID generation
        local uuid = generateUUID(filename, filepath)
        print("New UUID: " .. uuid)  -- Debug: Display new UUID
        copyToClipboard(uuid)
    end
    refreshStorageFile()
end




vim.keymap.set("n", "<leader>getid", ":lua callUUID()<CR>")

