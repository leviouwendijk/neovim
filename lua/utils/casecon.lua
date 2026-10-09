local M = {}

local notify = require("utils.notify")

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

M.config = {
    bin = "casecon",
    default_style = "snake",  -- camelCase → snake_case
    json_flag = "--json",
    convert_cmd = "convert",
}

-- ============================================================================
-- HELPER: Extract identifiers from Swift declarations
-- ============================================================================

--- Parse Swift let/var declarations and extract identifiers
--- Returns: { { name, line_content }, ... } preserving structure
---@param lines string[]
---@return table: { { name = "identifier", original_line = "let identifier: Type" }, ... }
local function extract_identifiers_from_swift(lines)
    local results = {}

    for index, line in ipairs(lines) do
        -- Match indentation, a keyword, and a candidate name only if it looks like a decl (… : or … =)
        local indent, keyword, name = line:match("^([ \t]*)(%a+)[ \t]+([%a_][%w_]*)[ \t]*[:=]")
        -- Only accept Swift decl keywords we care about
        if indent and (keyword == "let" or keyword == "var") and name then
            table.insert(results, {
                name = name,
                line_index = index,
                original_line = line,
                indent = indent,
                keyword = keyword,
            })
        end
    end

    return results
end
-- ============================================================================
-- HELPER: Call casecon binary via vim.system
-- ============================================================================

---@param identifiers string[] list of identifier names
---@param style string|nil target case style (defaults to "snake")
---@return table|nil: parsed JSON response { ok=bool, result=[...], error=string }
local function call_casecon(identifiers, style)
    if not identifiers or #identifiers == 0 then
        notify.warn("casecon: no identifiers to convert")
        return nil
    end

    style = style or M.config.default_style

    -- Build command: casecon convert --json --style <style> <id1> <id2> ...
    local cmd = {
        M.config.bin,
        M.config.convert_cmd,
        M.config.json_flag,
        "--style", style,
    }

    -- Append each identifier
    for _, id in ipairs(identifiers) do
        table.insert(cmd, id)
    end

    -- Execute synchronously via vim.system (Neovim 0.10+)
    local result = vim.system(cmd, { text = true }):wait()

    if result.code ~= 0 then
        local err_msg = result.stderr or "unknown error"
        notify.error("casecon failed: " .. err_msg)
        return nil
    end

    -- Parse JSON response
    local ok, decoded = pcall(vim.json.decode, result.stdout)
    if not ok then
        notify.error("casecon: failed to parse JSON response")
        return nil
    end

    if not decoded.ok then
        notify.error("casecon: " .. (decoded.error or "conversion failed"))
        return nil
    end

    return decoded
end

-- ============================================================================
-- HELPER: Replace identifiers in lines while preserving structure
-- ============================================================================
local function replace_identifiers_in_selection(extracted_info, converted_names, original_lines)
    if #extracted_info ~= #converted_names then
        notify.error("casecon: extracted count != converted count")
        return nil
    end

    -- Keep every original line, including non-declarations and blank lines.
    local out = vim.deepcopy(original_lines)

    for i, info in ipairs(extracted_info) do
        local original = original_lines[info.line_index]
        local prefix, old_name, suffix = original:match(
            "^([ \t]*%a+[ \t]+)([%a_][%w_]*)([ \t]*[:=].*)$"
        )
        local new_name = converted_names[i]

        if not prefix or old_name ~= info.name or type(new_name) ~= "string" then
            notify.error("casecon: declaration changed or invalid conversion result")
            return nil
        end

        out[info.line_index] = prefix .. new_name .. suffix
    end

    return out
end

-- ============================================================================
-- PUBLIC API: Main conversion function
-- ============================================================================

-- Default mode: convert the exact visual character selection, or a linewise
-- list of identifier-only lines. Do not implicitly parse Swift declarations.
function M.convert_selection(style, opts)
    if opts.range == 0 then
        notify.warn("casecon: select text first (visual mode), then use :Casecon")
        return
    end

    local first, last = opts.line1, opts.line2
    local _, mark_first, start_col = unpack(vim.fn.getpos("'<"))
    local _, mark_last, end_col = unpack(vim.fn.getpos("'>"))

    if vim.fn.visualmode() == "v" and first == mark_first and last == mark_last then
        if first ~= last then
            notify.warn("casecon: multiline characterwise selection is unsupported; select identifier lines with V")
            return
        end

        local line = vim.api.nvim_buf_get_lines(0, first - 1, first, false)[1]
        if not line or #line == 0 then
            notify.warn("casecon: empty selection")
            return
        end

        -- getpos columns are one-based byte offsets; the end mark is inclusive.
        -- Compute the exclusive end at a UTF-8 character boundary.
        local begin_byte = math.max(0, math.min(#line, start_col - 1))
        local final_byte = math.max(0, math.min(#line - 1, end_col - 1))
        if final_byte < begin_byte then
            notify.warn("casecon: invalid character selection")
            return
        end

        local end_byte = vim.fn.byteidx(line, vim.fn.charidx(line, final_byte) + 1)
        if end_byte < 0 then end_byte = #line end
        local selected = line:sub(begin_byte + 1, end_byte)

        local response = call_casecon({ selected }, style)
        if not response or type(response.result) ~= "table"
            or type(response.result[1]) ~= "string" or #response.result ~= 1 then
            return
        end

        vim.api.nvim_buf_set_text(0, first - 1, begin_byte, first - 1, end_byte, {
            response.result[1],
        })
        notify.info(("casecon: %s -> %s"):format(selected, response.result[1]))
        return
    end

    -- Linewise mode: only standalone identifiers and whitespace are admitted.
    -- Reject source-code lines rather than destructively converting them.
    local original = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
    local entries, names = {}, {}
    for index, line in ipairs(original) do
        local prefix, name, suffix = line:match("^([ \t]*)([%a_][%w_]*)([ \t]*)$")
        if name then
            entries[#entries + 1] = { index = index, prefix = prefix, suffix = suffix }
            names[#names + 1] = name
        elseif not line:match("^[ \t]*$") then
            notify.warn(("casecon: line %d is not a standalone identifier; use :CaseconDecl for Swift declarations"):format(first + index - 1))
            return
        end
    end

    if #names == 0 then
        notify.warn("casecon: no identifiers found in selected lines")
        return
    end

    local response = call_casecon(names, style)
    if not response or type(response.result) ~= "table" or #response.result ~= #names then
        notify.error("casecon: incomplete conversion response")
        return
    end

    local updated = vim.deepcopy(original)
    for index, entry in ipairs(entries) do
        local converted = response.result[index]
        if type(converted) ~= "string" then
            notify.error("casecon: invalid conversion response")
            return
        end
        updated[entry.index] = entry.prefix .. converted .. entry.suffix
    end

    vim.api.nvim_buf_set_lines(0, first - 1, last, false, updated)
    notify.info(("casecon: converted %d identifier(s)"):format(#names))
end

-- Explicit Swift let/var declaration mode. Preserve all unrecognized lines.
function M.convert_declarations(style, opts)
    local first, last = opts.line1, opts.line2
    local original = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
    local extracted = extract_identifiers_from_swift(original)

    if #extracted == 0 then
        notify.warn("casecon: no Swift let/var declarations found in range")
        return
    end

    local names = {}
    for _, item in ipairs(extracted) do
        names[#names + 1] = item.name
    end

    local response = call_casecon(names, style)
    if not response or type(response.result) ~= "table" then return end

    local updated = replace_identifiers_in_selection(extracted, response.result, original)
    if not updated then return end

    vim.api.nvim_buf_set_lines(0, first - 1, last, false, updated)
    notify.info(("casecon: converted %d Swift declaration(s)"):format(#names))
end

-- ============================================================================
-- USER COMMAND
-- ============================================================================

local function complete_style()
    return { "snake", "camel", "pascal" }
end

vim.api.nvim_create_user_command("Casecon", function(opts)
    M.convert_selection(vim.trim(opts.args) ~= "" and vim.trim(opts.args) or nil, opts)
end, {
    nargs = "?",
    range = true,
    complete = complete_style,
    desc = "Convert exact visual text or standalone identifier lines using casecon",
})

vim.api.nvim_create_user_command("CaseconDecl", function(opts)
    M.convert_declarations(vim.trim(opts.args) ~= "" and vim.trim(opts.args) or nil, opts)
end, {
    nargs = "?",
    range = true,
    complete = complete_style,
    desc = "Convert only Swift let/var declaration names within a line range",
})

vim.keymap.set("x", "<leader>ca", ":Casecon<Space>", {
    noremap = true,
    silent = false,
    desc = "Convert selected text with casecon (optional style)",
})

vim.keymap.set("x", "<leader>cd", ":CaseconDecl<Space>", {
    noremap = true,
    silent = false,
    desc = "Convert Swift declaration names in selected lines",
})

-- Add this temporary debug function to M
function M.debug_extract()
    local _, start_line, _, _ = unpack(vim.fn.getpos("'<"))
    local _, end_line, _, _ = unpack(vim.fn.getpos("'>"))

    local selected_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    vim.notify("=== DEBUG ===", vim.log.levels.INFO)
    vim.notify("Selection range: " .. start_line .. " to " .. end_line, vim.log.levels.INFO)
    vim.notify("Total lines: " .. #selected_lines, vim.log.levels.INFO)

    for i, line in ipairs(selected_lines) do
        vim.notify("Line " .. i .. ": [" .. line .. "]", vim.log.levels.INFO)
        vim.notify("  Length: " .. #line, vim.log.levels.INFO)
        vim.notify("  Bytes: " .. vim.fn.strdisplaywidth(line), vim.log.levels.INFO)

        -- Test the regex directly
        local indent, keyword, name = line:match("^([ \t]*)(%a+)[ \t]+([%a_][%w_]*)[ \t]*[:=]")
        if indent and (keyword == "let" or keyword == "var") then
            vim.notify("  ✓ MATCH: indent=[" .. indent .. "], keyword=[" .. keyword .. "], name=[" .. name .. "]", vim.log.levels.INFO)
        else
            vim.notify("  ✗ NO MATCH", vim.log.levels.WARN)
        end
    end
end

vim.api.nvim_create_user_command(
    "CaseconDebug",
    function()
        M.debug_extract()
    end,
    { range = true }
)

function M.debug_extract_to_buffer()
    local _, start_line, _, _ = unpack(vim.fn.getpos("'<"))
    local _, end_line, _, _ = unpack(vim.fn.getpos("'>"))

    local selected_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    local debug_output = {}
    table.insert(debug_output, "=== CASECON DEBUG ===")
    table.insert(debug_output, "Selection range: " .. start_line .. " to " .. end_line)
    table.insert(debug_output, "Total lines: " .. #selected_lines)
    table.insert(debug_output, "")

    for i, line in ipairs(selected_lines) do
        table.insert(debug_output, "Line " .. i .. ": [" .. line .. "]")
        table.insert(debug_output, "  Length: " .. #line)
        table.insert(debug_output, "  Display width: " .. vim.fn.strdisplaywidth(line))

        -- Show ALL character codes
        local char_codes = {}
        for j = 1, #line do
            table.insert(char_codes, string.format("%d", string.byte(line, j)))
        end
        table.insert(debug_output, "  Char codes (ALL): " .. table.concat(char_codes, ","))

        -- Test the regex directly
        local indent, keyword, name = line:match("^([ \t]*)(%a+)[ \t]+([%a_][%w_]*)[ \t]*[:=]")
        if indent and (keyword == "let" or keyword == "var") then
            table.insert(debug_output, "  ✓ MATCH: indent=[" .. indent .. "] (len=" .. #indent .. "), keyword=[" .. keyword .. "], name=[" .. name .. "]")
        else
            table.insert(debug_output, "  ✗ NO MATCH")
            table.insert(debug_output, "    Trying pattern without [:=]...")

            local i2, k2, n2 = line:match("^(%s*)(let|var)%s+([%w_]+)")
            if i2 and k2 and n2 then
                table.insert(debug_output, "    ✓ MATCH (without [:=]): indent=[" .. i2 .. "], keyword=[" .. k2 .. "], name=[" .. n2 .. "]")
            else
                table.insert(debug_output, "    ✗ NO MATCH (even without [:=])")
            end
        end
        table.insert(debug_output, "")
    end

    table.insert(debug_output, "=== END DEBUG ===")

    -- Insert at end of buffer
    vim.api.nvim_buf_set_lines(0, -1, -1, false, debug_output)
end

vim.api.nvim_create_user_command(
    "CaseconDebugBuffer",
    function()
        M.debug_extract_to_buffer()
    end,
    { range = true }
)

require("utils.casecon-substitute")(M.config, notify)

return M

-- " Convert visual selection to snake_case (default)
-- :'<,'>Casecon

-- " Convert to camelCase
--     :'<,'>Casecon camel

-- " Convert to PascalCase
-- :'<,'>Casecon pascal

--     let hashedToken: String
--     let ipAddress: String
--     let maxUsages: Int = 0

--     let hashed_token: String
--     let ip_address: String
--     let max_usages: Int = 0

-- require("utils.casecon")
