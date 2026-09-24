local uv = vim.uv or vim.loop

local M = {}

function M.normalize_path(path)
    return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

function M.path_is_within(path, root)
    if path == root then
        return true
    end

    if root == "/" then
        return path:sub(1, 1) == "/"
    end

    return path:sub(1, #root + 1) == root .. "/"
end

function M.destination_for(source, target_dir)
    return vim.fs.joinpath(target_dir, vim.fs.basename(source))
end

function M.compact_sources(marked_paths)
    local candidates = {}
    local seen = {}

    for _, raw_path in ipairs(marked_paths) do
        local path = M.normalize_path(raw_path)

        if not seen[path] then
            local stat = uv.fs_lstat(path)
            table.insert(candidates, {
                path = path,
                kind = stat and stat.type or nil,
            })
            seen[path] = true
        end
    end

    table.sort(candidates, function(lhs, rhs)
        if #lhs.path == #rhs.path then
            return lhs.path < rhs.path
        end
        return #lhs.path < #rhs.path
    end)

    local compacted = {}

    for _, candidate in ipairs(candidates) do
        local covered = false

        for _, parent in ipairs(compacted) do
            if parent.kind == "directory"
                and M.path_is_within(candidate.path, parent.path)
            then
                covered = true
                break
            end
        end

        if not covered then
            table.insert(compacted, candidate)
        end
    end

    return compacted
end

function M.target_is_blocked(path, sources)
    for _, source in ipairs(sources) do
        if source.kind == "directory"
            and M.path_is_within(path, source.path)
        then
            return true
        end
    end

    return false
end

function M.list_directories(dir, sources)
    local directories = {}
    local handle = uv.fs_scandir(dir)

    if not handle then
        return directories
    end

    while true do
        local name, kind = uv.fs_scandir_next(handle)
        if not name then
            break
        end

        if kind == "directory" then
            local full_path = M.normalize_path(
                vim.fs.joinpath(dir, name)
            )

            if not M.target_is_blocked(full_path, sources) then
                table.insert(directories, full_path)

                for _, subdirectory in ipairs(
                    M.list_directories(full_path, sources)
                ) do
                    table.insert(directories, subdirectory)
                end
            end
        end
    end

    return directories
end

function M.target_directories(cwd, sources)
    local directories = {}

    if not M.target_is_blocked(cwd, sources) then
        table.insert(directories, cwd)
    end

    for _, directory in ipairs(M.list_directories(cwd, sources)) do
        table.insert(directories, directory)
    end

    return directories
end

function M.move_entry(source, target_dir)
    local source_path = source.path
    local source_stat = uv.fs_lstat(source_path)

    if not source_stat then
        return {
            status = "error",
            source = source_path,
            message = "Source no longer exists",
        }
    end

    local target_stat = uv.fs_stat(target_dir)
    if not target_stat or target_stat.type ~= "directory" then
        return {
            status = "error",
            source = source_path,
            message = "Target directory no longer exists",
        }
    end

    if source_stat.type == "directory"
        and M.path_is_within(target_dir, source_path)
    then
        return {
            status = "error",
            source = source_path,
            message = "Cannot move a directory into itself or one of its descendants",
        }
    end

    local target_path = M.destination_for(source_path, target_dir)

    if source_path == target_path then
        return {
            status = "noop",
            source = source_path,
            destination = target_path,
            kind = source_stat.type,
        }
    end

    if uv.fs_lstat(target_path) then
        return {
            status = "error",
            source = source_path,
            destination = target_path,
            message = "Destination already exists",
        }
    end

    local ok, err, code = uv.fs_rename(source_path, target_path)
    if not ok then
        local detail = tostring(code or err or "unknown error")
        local cross_device =
        detail:find("EXDEV", 1, true)
        or detail:lower():find("cross-device", 1, true)

        return {
            status = "error",
            source = source_path,
            destination = target_path,
            code = cross_device and "cross_device" or code,
            message = cross_device
                and "Cross-filesystem moves are not supported yet"
                or detail,
        }
    end

    return {
        status = "moved",
        source = source_path,
        destination = target_path,
        kind = source_stat.type,
    }
end

return M
