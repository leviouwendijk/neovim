local SwiftInitializer = {}

-- Helper: trim whitespace from both ends
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Helper: replace a 1-based range [start_line, end_line] with new lines
function SwiftInitializer.replace_range(bufnr, start_line, end_line, lines)
    -- Convert to 0-based [start-1, end]
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, lines)
end

-- Helper: insert a list of lines after a given 1-based buffer line
function SwiftInitializer.insert_after(bufnr, line_num, lines)
    -- To insert after `line_num` (1-based), use index = line_num (0-based).
    vim.api.nvim_buf_set_lines(bufnr, line_num, line_num, false, lines)
end

-- Main function: read the given line range, parse properties, and insert init below
function SwiftInitializer.generate_public_init(opts)
    local bufnr      = vim.api.nvim_get_current_buf()
    local start_line = opts.line1  -- 1-based
    local end_line   = opts.line2  -- 1-based

    -- Read exactly those lines from the buffer
    local raw_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

    -- Determine indentation from the first selected line
    local first_raw = raw_lines[1] or ""
    local indent = first_raw:match("^(%s*)") or ""

    -- Helper to strip comments (// ... and /* ... */) from a single line
    local function strip_comments(s)
        -- remove block comments that are fully on this line
        s = s:gsub("/%*.-%*/", "")
        -- remove inline comments
        s = s:gsub("%s*//.*$", "")
        return s
    end

    -- Collect (name, type) pairs
    local fields = {}
    for _, line in ipairs(raw_lines) do
        local ln = trim(strip_comments(line or ""))
        if ln ~= "" then
            -- Split ln by whitespace into tokens
            local tokens = {}
            for tok in ln:gmatch("%S+") do
                table.insert(tokens, tok)
            end

            -- Determine where “let” or “var” sits (possibly after leading “public”)
            local i = 1
            if tokens[1] == "public" then
                i = 2
            end

            if tokens[i] == "let" or tokens[i] == "var" then
                local name_tok = tokens[i + 1] or ""
                -- Must end with a colon
                if name_tok:sub(-1) == ":" then
                    local name = name_tok:sub(1, -2)
                    -- Everything after the first colon in ln is the type
                    local colon_pos = ln:find(":", 1, true)
                    if colon_pos then
                        local typ = trim(ln:sub(colon_pos + 1))
                        table.insert(fields, { name = name, typ = typ })
                    end
                end
            end
            -- Lines that don’t match are skipped
        end
    end

    if #fields == 0 then
        vim.notify("No valid properties found in selection.", vim.log.levels.WARN)
        return
    end

    -- Build the “public init( … ) { … }” block, preserving indentation
    local out_lines = {}

    -- 1) blank line with same indent
    table.insert(out_lines, indent)

    -- 2) "public init("
    table.insert(out_lines, indent .. "public init(")

    -- 3) parameters
    for i, f in ipairs(fields) do
        local comma = (i < #fields) and "," or ""
        table.insert(
            out_lines,
            indent .. "    " .. string.format("%s: %s%s", f.name, f.typ, comma)
        )
    end

    -- 4) closing parenthesis and brace
    table.insert(out_lines, indent .. ") {")

    -- 5) assignments
    for _, f in ipairs(fields) do
        table.insert(
            out_lines,
            indent .. "    " .. string.format("self.%s = %s", f.name, f.name)
        )
    end

    -- 6) closing brace
    table.insert(out_lines, indent .. "}")

    -- Insert these lines *after* the selected range
    SwiftInitializer.insert_after(bufnr, end_line, out_lines)
end

-- Create a :SwiftInit command that accepts a range
vim.api.nvim_create_user_command("SwiftInit", function(opts)
    SwiftInitializer.generate_public_init(opts)
end, {
range = true,
})

-- Visual-mode mapping: <leader>gi ⇒ :SwiftInit
vim.keymap.set(
    "v",
    "<leader>gi",
    ":SwiftInit<CR>",
    { noremap = true, silent = true }
)

return SwiftInitializer
