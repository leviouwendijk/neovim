return function(context)
    local funcs = context.funcs
    local lsp_zero = context.lsp_zero

    vim.diagnostic.config(
        {
            virtual_text = { spacing = 2, prefix = "●" },
            signs = true,
            underline = true,
            update_in_insert = false,
            severity_sort = true,
            float = {
                focusable = false,
                border = "rounded",
                source = true,
                -- source = "if_many",  -- valid values: true | false | "if_many"
                header = "",
                prefix = "",
            },
        }
    )

    local function diag_jump(delta, severity)
        return function()
            local opts = { count = delta, float = true } -- float=true shows the message on jump
            if severity then
                opts.severity = vim.diagnostic.severity[severity]
            end
            vim.diagnostic.jump(opts)
        end
    end

    -- === Diagnostic → clipboard helpers ===
    local function _diag_at_cursor()
        local bufnr = vim.api.nvim_get_current_buf()
        local pos   = vim.api.nvim_win_get_cursor(0)
        local lnum  = pos[1] - 1
        local col   = pos[2]

        local diags = vim.diagnostic.get(bufnr, { lnum = lnum })
        if #diags == 0 then return nil end

        -- Prefer a diagnostic that actually covers the cursor column; else fallback.
        local covering = {}
        for _, d in ipairs(diags) do
            local s = d.col or 0
            local e = d.end_col or (s + 1)
            if col >= s and col < e then table.insert(covering, d) end
        end
        local pool = (#covering > 0) and covering or diags
        table.sort(pool, function(a, b) return (a.severity or 99) < (b.severity or 99) end)
        return pool[1]
    end

    --
    -- Enhanced diagnostic -> text with context / code snippet and caret pointer
    local CTX_LINES = 2           -- number of lines of context to include
    local MAX_LINE_LEN = 200      -- truncate very long lines for clipboard

    local function _escape_markdown(s)
        if not s then return "" end
        -- Minimal markdown escape for backticks and leading/trailing spaces
        s = tostring(s)
        s = s:gsub("```", "`​``")   -- avoid closing triple-backtick in content (zero-width)
        return s
    end

    local function _get_snippet_with_caret(bufnr, lnum0, col0, ctx)
        -- bufnr: buffer number (0-based)
        -- lnum0, col0: 0-based line and column positions
        ctx = ctx or CTX_LINES

        local total = vim.api.nvim_buf_line_count(bufnr)
        local start_line = math.max(0, lnum0 - ctx)
        local end_line = math.min(total - 1, lnum0 + ctx)

        local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

        -- compute width for line numbers (1-based)
        local width = #tostring(end_line + 1)
        local out_lines = {}
        for i, ln in ipairs(lines) do
            local abs_ln = start_line + i -- 1-based
            local text = ln
            if #text > MAX_LINE_LEN then
                text = text:sub(1, MAX_LINE_LEN - 3) .. "..."
            end
            table.insert(out_lines, string.format("%" .. width .. "d | %s", abs_ln, text))
        end

        -- caret line: create spaces to align under column (approximate because of tabs)
        local caret_line = nil
        if lnum0 >= start_line and lnum0 <= end_line then
            local rel_index = lnum0 - start_line + 1
            local marker_col = col0 or 0
            -- estimate prefix width: digits + " | " = width + 3
            local prefix = string.rep(" ", width + 3)
            -- we replace tabs so caret aligns better (tab -> single space). Not perfect for mixed tabs, but helpful.
            local target_line = lines[rel_index] or ""
            local pre_substr = target_line:sub(1, math.max(0, marker_col))
            pre_substr = pre_substr:gsub("\t", " ") -- normalize
            local padding = prefix .. pre_substr:gsub(".", function(c) return (c == "\t") and " " or " " end)
            -- But rather than trying to count grapheme widths exactly, place caret under the column index (best-effort)
            caret_line = padding .. "^"
        end

        return table.concat(out_lines, "\n"), caret_line
    end

    local function _diag_to_text(d)
        if not d then return nil end

        local sevname = {
            [vim.diagnostic.severity.ERROR] = "ERROR",
            [vim.diagnostic.severity.WARN]  = "WARN",
            [vim.diagnostic.severity.INFO]  = "INFO",
            [vim.diagnostic.severity.HINT]  = "HINT",
        }

        -- best effort to get a filename
        local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(d.bufnr or 0), ":.")
        if fname == "" then fname = "(no file)" end

        local lnum = (d.lnum or 0)        -- 0-based
        local col  = (d.col or 0)         -- 0-based

        -- header: [SEV] path:line:col
        local header = string.format("[%s] %s:%d:%d",
            sevname[d.severity] or "?",
            fname,
            (lnum or 0) + 1,
            (col  or 0) + 1
        )

        -- message: flatten and tidy whitespace
        local message = (d.message or "")
        message = message:gsub("%s+\n", " "):gsub("\n", " ")
        message = _escape_markdown(message)

        -- snippet with caret (if buffer available)
        local snippet = nil
        local caret = nil
        local ok, snippet_text = pcall(function()
            -- if buffer not loaded, try to use d.bufnr; else fallback to reading file
            local b = d.bufnr and vim.api.nvim_buf_is_loaded(d.bufnr) and d.bufnr or nil
            if not b then
                -- try to load file contents into a temporary buffer
                local path = vim.api.nvim_buf_get_name(d.bufnr or 0)
                if path and #path > 0 then
                    local tmp = vim.fn.bufadd(path)
                    vim.fn.bufload(tmp)
                    b = tmp
                end
            end
            if b then
                return _get_snippet_with_caret(b, lnum, col, CTX_LINES)
            end
            return nil
        end)

        if ok and snippet_text and snippet_text ~= "" then
            snippet, caret = snippet_text:match("^(.*)\n(.*)$")
            -- Actually _get_snippet_with_caret returns (lines, caret); but our pcall returned that as single value
            -- So adjust: if snippet_text is a table return, handle both cases. Simpler: call directly and unpack.
            snippet, caret = _get_snippet_with_caret(d.bufnr or 0, lnum, col, CTX_LINES)
        end

        -- code id (LSP): pull from several possible places
        local code = d.code or (d.user_data and d.user_data.lsp and d.user_data.lsp.code) or (d.user_data and d.user_data.code)

        -- tail pieces
        local tail = {}
        if d.source then table.insert(tail, "source=" .. d.source) end
        if code then table.insert(tail, "code=" .. tostring(code)) end
        table.insert(tail, "ts=" .. os.date("!%Y-%m-%dT%H:%M:%SZ")) -- UTC timestamp

        -- Build Markdown-friendly text:
        local parts = {}
        table.insert(parts, header)
        if snippet and snippet ~= "" then
            table.insert(parts, "```")
            table.insert(parts, snippet)
            if caret then table.insert(parts, caret) end
            table.insert(parts, "```")
        end
        table.insert(parts, "> " .. message)
        table.insert(parts, "(" .. table.concat(tail, " ") .. ")")

        return table.concat(parts, "\n\n")
    end

    -- copy single diagnostic
    local function copy_current_diagnostic()
        local d = _diag_at_cursor()
        if not d then
            funcs.safe_notify("No diagnostics on this line.", vim.log.levels.INFO)
            return
        end
        local text = _diag_to_text(d)
        if not text then
            funcs.safe_notify("Failed to format diagnostic.", vim.log.levels.WARN)
            return
        end

        vim.fn.setreg("+", text)   -- system clipboard
        vim.fn.setreg('"', text)   -- default yank register

        if type(_G.Copier) == "table"
            and type(_G.Copier.push_clipboard) == "function"
            and _G.Copier.master_copier_enable
        then pcall(_G.Copier.push_clipboard) end

        funcs.safe_notify("Diagnostic copied.", vim.log.levels.INFO)
    end

    local function open_float_and_copy()
        vim.diagnostic.open_float()
        copy_current_diagnostic()
    end

    -- copy all diagnostics in buffer, grouped by file, with counts and context
    local function copy_buffer_diags(severity)  -- severity: "ERROR"|"WARN"|"INFO"|"HINT"|nil
        return function()
            local bufnr = vim.api.nvim_get_current_buf()
            local filter = {}
            if severity then filter.severity = vim.diagnostic.severity[severity] end

            local diags = vim.diagnostic.get(bufnr, filter)
            if #diags == 0 then
                funcs.safe_notify("No diagnostics" .. (severity and (" ("..severity..")") or "") .. " in buffer.", vim.log.levels.INFO)
                return
            end

            -- Group diagnostics by file path (repo-relative)
            local grouped = {}
            for _, d in ipairs(diags) do
                d.bufnr = d.bufnr or bufnr
                local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(d.bufnr), ":.")
                if path == "" then path = "(no file)" end
                grouped[path] = grouped[path] or {}
                table.insert(grouped[path], d)
            end

            local out_chunks = {}
            for path, list in pairs(grouped) do
                table.insert(out_chunks, string.format("## %s (%d diagnostic%s)", path, #list, (#list == 1 and "" or "s")))
                for _, d in ipairs(list) do
                    table.insert(out_chunks, _diag_to_text(d))
                end
            end

            local text = table.concat(out_chunks, "\n\n---\n\n")
            vim.fn.setreg("+", text)
            vim.fn.setreg('"', text)

            if type(_G.Copier) == "table"
                and type(_G.Copier.push_clipboard) == "function"
                and _G.Copier.master_copier_enable
            then pcall(_G.Copier.push_clipboard) end

            funcs.safe_notify(("Copied %d diagnostic%s%s."):format(
                #diags, (#diags==1 and "" or "s"), severity and (" ("..severity..")") or ""
            ), vim.log.levels.INFO)
        end
    end

    -- new helpers end

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

    lsp_zero.on_attach(function(client, bufnr)
        local opts = {buffer = bufnr, remap = false}

        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
        vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
        -- vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
        -- vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)

        -- BEGIN OF NEW
        -- yank diagnostic under cursor
        vim.keymap.set("n", "<leader>vy", copy_current_diagnostic, opts)

        -- open float and also copy it
        vim.keymap.set("n", "<leader>vD", open_float_and_copy, opts)

        -- copy ALL diags in buffer
        vim.keymap.set("n", "<leader>vA", copy_buffer_diags(), opts)

        -- copy only specific severities
        vim.keymap.set("n", "<leader>vE", copy_buffer_diags("ERROR"), opts)
        vim.keymap.set("n", "<leader>vW", copy_buffer_diags("WARN"),  opts)
        vim.keymap.set("n", "<leader>vI", copy_buffer_diags("INFO"),  opts)
        vim.keymap.set("n", "<leader>vH", copy_buffer_diags("HINT"),  opts)
        -- EONEW

        vim.keymap.set("n", "[d", diag_jump(-1), opts)
        vim.keymap.set("n", "]d", diag_jump( 1), opts)

        vim.keymap.set("n", "[e", diag_jump(-1, "ERROR"), opts)
        vim.keymap.set("n", "]e", diag_jump( 1, "ERROR"), opts)

        vim.keymap.set("n", "[w", diag_jump(-1, "WARN"),  opts)
        vim.keymap.set("n", "]w", diag_jump( 1, "WARN"),  opts)

        vim.keymap.set("n", "[i", diag_jump(-1, "INFO"),  opts)
        vim.keymap.set("n", "]i", diag_jump( 1, "INFO"),  opts)

        vim.keymap.set("n", "[h", diag_jump(-1, "HINT"),  opts)
        vim.keymap.set("n", "]h", diag_jump( 1, "HINT"),  opts)

        vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)

        -- new for checking source lib
        vim.keymap.set("n", "<leader>vL", symbol_library_preview, {
            buffer = bufnr,
            silent = true,
            desc = "Symbol → Library",
        })
    end)
end
