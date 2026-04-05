local VAT = {}

local ns_id = vim.api.nvim_create_namespace("vat")

local allowed_extensions = {
    ec     = true,
    entry  = true,
    txt    = true,
    ledger = true,
}

-- Function to calculate VAT (assuming 21% rate)
local function calculate_vat(amount, vat_rate)
    return amount - ( amount / ( 1.00 + vat_rate ) )
end

local function calculate_revenue(amount, vat_rate)
    return ( amount / ( 1.00 + vat_rate ) )
end

local function extract_vat_rate(line)
    local vat_rate = line:match("//%s*v?%a*:?%s*(%d+%.?%d*)%%")
    return vat_rate and (tonumber(vat_rate) / 100) or 0.21 -- Convert to decimal
end

-- Function to find debit/credit amounts in a given line
local function extract_amount(line)
    local amount = line:match("%d+%.?%d*")
    return tonumber(amount)
end

local function get_vat_text(vat, revenue, vat_rate)
    local format_setting = 2

    if format_setting == 1 then
        return string.format(" VAT (%.0f%%): %.2f", vat_rate * 100, vat) -- Full format
    elseif format_setting == 2 then
        return string.format(" %.2f (%.0f%%) & %.2f", vat, vat_rate * 100, revenue) -- VATinimal format
    else
        return string.format(" VAT: %.2f", vat) -- Fallback default
    end
end

-- Function to process and display VAT dynamically
VAT.show_vat = function()
    local bufnr = vim.api.nvim_get_current_buf()

    -- adding filtering by allowed_extensions
    local name = vim.api.nvim_buf_get_name(bufnr)
    local ext = name:match("^.+%.([^.]+)$")
    if not ext or not allowed_extensions[ext:lower()] then
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        return
    end

    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local line_nr = cursor_pos[1] - 1 -- Neovim uses 0-based indexing
    local line = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)[1]

    -- Check if line contains financial operations
    if line and (line:match("debit") or line:match("credit") or line:match("add") or line:match("sub")) then
        local amount = extract_amount(line)
        local vat_rate = extract_vat_rate(line) -- Extract VAT rate (or use default 0.21)

        if amount then
            local vat = calculate_vat(amount, vat_rate)
            local revenue = calculate_revenue(amount, vat_rate)
            local vat_text = get_vat_text(vat, revenue, vat_rate)

            -- Remove previous extmarks in the namespace
            vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

            -- Add virtual text displaying VAT dynamically
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_nr, #line, {
                virt_text = { { vat_text, "Comment" } }, -- Display VAT as virtual text
                hl_mode = "combine",
            })
        end
    end
end

-- Auto-trigger VAT calculation on cursor move
vim.api.nvim_create_autocmd("CursorMoved", {
    -- pattern = "*.txt,*.entry", -- Adjust based on file type
    callback = function()
        VAT.show_vat()
    end,
})

return VAT
