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

    for _, line in ipairs(lines) do
        -- Match indentation, a keyword, and a candidate name only if it looks like a decl (… : or … =)
        local indent, keyword, name = line:match("^([ \t]*)(%a+)[ \t]+([%a_][%w_]*)[ \t]*[:=]")
        -- Only accept Swift decl keywords we care about
        if indent and (keyword == "let" or keyword == "var") and name then
            table.insert(results, {
                name = name,
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
local function escape_lua_magic(s)
    -- Escape Lua pattern magic characters
    return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"))
end

local function replace_identifiers_in_selection(extracted_info, converted_names)
    if #extracted_info ~= #converted_names then
        notify.error("casecon: extracted count != converted count (internal error)")
        return nil
    end

    local out = {}

    for i, info in ipairs(extracted_info) do
        local old_name = info.name
        local new_name = converted_names[i]
        local line     = info.original_line

        -- Build a pattern that targets ONLY the decl identifier right after the keyword.
        --  ^([ \t]*)   -> capture indent (not used, but keeps the anchor honest)
        --  keyword[ \t]+
        --  (old_name)  -> capture the identifier token we want to replace
        --  ([ \t]*[:=])-> ensure it's a decl (colon type or equals initializer)
        local pat = "^([ \t]*)" .. info.keyword .. "[ \t]+(" .. escape_lua_magic(old_name) .. ")([ \t]*[:=])"

        -- Replace just that identifier token; keep indent, keyword spacing, and the following punctuation intact
        local replaced, n = line:gsub(pat, "%1" .. info.keyword .. " " .. new_name .. "%3")

        -- Fallback: if not matched (e.g. weird spacing), try a looser variant
        if n == 0 then
            local pat_loose = "^([ \t]*)" .. info.keyword .. "[ \t]+(" .. escape_lua_magic(old_name) .. ")(.*[:=])"
            replaced = (line:gsub(pat_loose, "%1" .. info.keyword .. " " .. new_name .. "%3"))
        end

        table.insert(out, replaced)
    end

    return out
end

-- ============================================================================
-- PUBLIC API: Main conversion function
-- ============================================================================

---@param style string|nil: target case style (defaults to config.default_style)
function M.convert_selection(style)
    -- Get the current selection bounds
    local _, start_line, start_col, _ = unpack(vim.fn.getpos("'<"))
    local _, end_line, end_col, _ = unpack(vim.fn.getpos("'>"))

    if start_line > end_line or (start_line == end_line and start_col > end_col) then
        notify.warn("casecon: invalid selection")
        return
    end

    -- Read selected lines
    local selected_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    if not selected_lines or #selected_lines == 0 then
        notify.warn("casecon: no lines in selection")
        return
    end

    -- Extract identifiers
    local extracted_info = extract_identifiers_from_swift(selected_lines)

    if #extracted_info == 0 then
        notify.warn("casecon: no identifiers found in selection")
        return
    end

    -- Collect just the names
    local names = {}
    for _, info in ipairs(extracted_info) do
        table.insert(names, info.name)
    end

    -- Call casecon
    local response = call_casecon(names, style)
    if not response or not response.result then
        return
    end

    -- Replace in selection
    local modified_lines = replace_identifiers_in_selection(extracted_info, response.result)
    if not modified_lines then
        return
    end

    -- Write back to buffer
    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, modified_lines)

    notify.info(("casecon: converted %d identifier(s) to %s"):format(#names, style or M.config.default_style))
end

-- ============================================================================
-- USER COMMAND
-- ============================================================================

vim.api.nvim_create_user_command(
    "Casecon",
    function(opts)
        local style = opts.args ~= "" and opts.args or nil
        M.convert_selection(style)
    end,
    {
        nargs = "?",
        range = true,
        complete = function()
            return { "snake", "camel", "pascal" }
        end,
        desc = "Convert identifiers in selection using casecon (snake|camel|pascal, default: snake)",
    }
)

-- ============================================================================
-- OPTIONAL: Visual-mode keybinding (uncomment to enable)
-- ============================================================================

vim.keymap.set("v", "<leader>ca", ":Casecon<Space>", {
    noremap = true,
    silent = false,
    desc = "Convert selection with casecon (append snake|camel|pascal)",
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
