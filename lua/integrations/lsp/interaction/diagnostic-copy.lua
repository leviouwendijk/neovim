return function(context)
    local funcs = context.funcs

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

    return {
        copy_current = copy_current_diagnostic,
        open_float_and_copy = open_float_and_copy,
        copy_buffer = copy_buffer_diags,
    }
end
