return function(context)
    local funcs = context.funcs

    -- lib checker (custom)
    -- === Symbol → Library inspector =============================================
    local function _raw_checkout_from_path(path)
        if not path then return nil end
        -- match: .../.build/index-build/checkouts/<RAW>/...
        local m = path:match("/%.build/index%-build/checkouts/([^/]+)/")
        return m
    end

    local function _infer_library_from_uri(uri)
        if not uri then return nil end
        local path = vim.uri_to_fname(uri)

        -- SPM checkouts (SwiftPM)
        local m = path:match("/%.build/checkouts/([^/]+)/")
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

    local function make_position_params_safe(client, win)
        local enc = client.offset_encoding or "utf-16"
        win = win or 0
        local params = vim.lsp.util.make_position_params(win, enc)
        return params
    end

    local function symbol_library_preview()
        local bufnr = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = bufnr })  -- new API
        if #clients == 0 then
            funcs.safe_notify("No LSP client attached.", vim.log.levels.WARN)
            return
        end

        -- Prefer a client that supports definitionProvider
        local client
        for _, c in ipairs(clients) do
            if c.server_capabilities and c.server_capabilities.definitionProvider then
                client = c
                break
            end
        end
        client = client or clients[1]

        local params = make_position_params_safe(client, 0)

        -- Method call (self): use colon syntax
        local resp = client:request_sync('textDocument/definition', params, 500, bufnr)
        if not resp or not resp.result then
            funcs.safe_notify("No definition found for symbol under cursor.", vim.log.levels.INFO)
            return
        end

        local defs = resp.result
        if not vim.islist(defs) then defs = { defs } end

        local seen = {}
        local lines = {}
        table.insert(lines, "**Symbol Declaration Info**")
        table.insert(lines, "")  -- placeholder; we may insert "in <raw>:" after we discover it

        local ctx_checkout = nil

        for _, d in ipairs(defs) do
            local uri = d.uri or d.targetUri
            local lib, kind, path = _infer_library_from_uri(uri)
            local range = d.range or d.targetRange
            local start = range and range.start
            local loc = ""
            if start then
                loc = (start.line + 1) .. ":" .. (start.character + 1)
            end

            -- capture RAW dir when coming from .build/index-build/checkouts/<RAW>/...
            if not ctx_checkout then
                ctx_checkout = _raw_checkout_from_path(path)
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

        vim.lsp.util.open_floating_preview(lines, "markdown", {
            border = "rounded",
            focusable = false,
        })
    end

    vim.api.nvim_create_user_command("SymbolLibrary", function()
        symbol_library_preview()
    end, { desc = "Show which library the symbol under cursor belongs to" })
    -- ============================================================================

    return {
        preview = symbol_library_preview,
    }
end
