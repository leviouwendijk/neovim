local M = {}

local function raw_checkout_from_path(path)
    if not path then return nil end
    -- match: .../.build/index-build/checkouts/<RAW>/...
    local m = path:match("/%.build/index%-build/checkouts/([^/]+)/")
    return m
end

function M.infer_library_from_uri(uri)
    if not uri then return nil end
    local path = vim.uri_to_fname(uri)

    -- SPM checkouts (SwiftPM)
    local m = path:match("/%.build/index%-build/checkouts/([^/]+)/")
    if m then return m, "spm", path end

    m = path:match("/%.build/checkouts/([^/]+)/")
    if m then return m, "spm", path end

    -- Xcode SPM cache
    m = path:match("/SourcePackages/checkouts/([^/]+)/")
    if m then return m, "spm", path end

    -- Local SwiftPM module
    m = path:match("/Sources/([^/]+)/")
    if m then return m, "local", path end

    -- Toolchain / SDK modules
    m = path:match("/usr/lib/swift/([^/]+)/")
    if m then return m, "toolchain", path end
    m = path:match("/Toolchains/[^/]+/usr/lib/swift/([^/]+)/")
    if m then return m, "toolchain", path end

    -- Fallback: file name
    return vim.fn.fnamemodify(path, ":t"), "file", path
end

function M.definition_client(clients)
    for _, client in ipairs(clients or {}) do
        if
            client.server_capabilities
            and client.server_capabilities.definitionProvider
        then
            return client
        end
    end

    return nil
end

function M.normalize_definitions(result)
    if result == nil then
        return {}
    end

    if vim.islist(result) then
        return result
    end

    return { result }
end

function M.definition_lines(result)
    local defs = M.normalize_definitions(result)
    if #defs == 0 then
        return nil
    end

    local seen = {}
    local lines = {}
    table.insert(lines, "**Symbol Declaration Info**")
    table.insert(lines, "")  -- placeholder; we may insert "in <raw>:" after we discover it

    local ctx_checkout = nil

    for _, d in ipairs(defs) do
        local uri = d.uri or d.targetUri
        local lib, kind, path = M.infer_library_from_uri(uri)
        local range = d.range or d.targetRange
        local start = range and range.start
        local loc = ""
        if start then
            loc = (start.line + 1) .. ":" .. (start.character + 1)
        end

        -- capture RAW dir when coming from .build/index-build/checkouts/<RAW>/...
        if not ctx_checkout then
            ctx_checkout = raw_checkout_from_path(path)
        end

        local key = (lib or "?") .. "|" .. (kind or "?")
        if not seen[key] then
            seen[key] = true
            -- rename: Library -> Parent
            table.insert(lines, ("- **Parent:** %s  _(%s)_"):format(lib or "?", kind or "?"))
        end
        table.insert(lines, ("  - `%s`%s"):format(path or "?", loc ~= "" and (" ➜ " .. loc) or ""))
    end

    -- If we discovered a RAW checkout dir, show it near the top: "in <raw>:"
    if ctx_checkout then
        table.insert(lines, 2, ("in **%s**:"):format(ctx_checkout))
    end

    return lines
end

return M
