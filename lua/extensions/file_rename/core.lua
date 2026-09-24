local uv = vim.uv or vim.loop

local M = {}

function M.normalize_path(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    local absolute = vim.fn.fnamemodify(path, ":p")
    local normalized = vim.fs.normalize(absolute)

    if normalized ~= "/" then
        normalized = normalized:gsub("/+$", "")
    end

    return normalized
end

function M.destination_for(directory, name)
    local root = M.normalize_path(directory)

    if not root
        or type(name) ~= "string"
        or name == ""
    then
        return nil
    end

    return M.normalize_path(
        vim.fs.joinpath(root, name)
    )
end

function M.rename(source, destination)
    source = M.normalize_path(source)
    destination = M.normalize_path(destination)

    if not source then
        return {
            status = "error",
            message = "Invalid source path",
        }
    end

    if not destination then
        return {
            status = "error",
            source = source,
            message = "Invalid destination path",
        }
    end

    if source == destination then
        return {
            status = "noop",
            source = source,
            destination = destination,
        }
    end

    if not uv.fs_lstat(source) then
        return {
            status = "error",
            source = source,
            destination = destination,
            message = "Source does not exist",
        }
    end

    if uv.fs_lstat(destination) then
        return {
            status = "error",
            source = source,
            destination = destination,
            message = "Destination already exists",
        }
    end

    local ok, err, code = uv.fs_rename(
        source,
        destination
    )

    if not ok then
        return {
            status = "error",
            source = source,
            destination = destination,
            message = tostring(err or code or "Rename failed"),
        }
    end

    return {
        status = "renamed",
        source = source,
        destination = destination,
    }
end

function M.rename_in_directory(
    directory,
    old_name,
    new_name
)
    local source = M.destination_for(
        directory,
        old_name
    )
    local destination = M.destination_for(
        directory,
        new_name
    )

    return M.rename(
        source,
        destination
    )
end

return M
