local M = {}

M.home = vim.uv.os_homedir() or os.getenv("HOME") or ""

local function flatten(parts, out)
    out = out or {}
    for _, part in ipairs(parts) do
        if type(part) == "table" then
            flatten(part, out)
        elseif part ~= nil and part ~= "" then
            table.insert(out, tostring(part))
        end
    end
    return out
end

function M.join(...)
    local parts = flatten({ ... })
    if #parts == 0 then
        return ""
    end

    local joined = table.concat(parts, "/")
    joined = joined:gsub("//+", "/")
    return joined
end

function M.home_join(...)
    if M.home == "" then
        return M.join(...)
    end
    return M.join(M.home, ...)
end

function M.expand(p)
    if not p or p == "" then
        return ""
    end
    if p == "~" then
        return M.home
    end
    if p:sub(1, 2) == "~/" then
        return M.join(M.home, p:sub(3))
    end
    return p
end

function M.normalize(p)
    p = M.expand(p)
    if p == "" then
        return ""
    end
    return vim.fs.normalize(p)
end

function M.glob(root, suffix)
    root = M.normalize(root)
    suffix = suffix or "/**"
    return root .. suffix
end

function M.is_relative_to(file, dir)
    file = M.normalize(file)
    dir = M.normalize(dir)

    if file == "" or dir == "" then
        return false
    end

    return file == dir or file:sub(1, #dir + 1) == dir .. "/"
end

return M
