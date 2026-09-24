return function(context)
    local M = {}
    local config = context.config
    local header = context.header

    -- ---------- public API ------------------------------------------------------

    -----@param buf integer
    -----@param ts number|nil
    --function M.refresh_header(buf, ts)
    --    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
    --    local hdr = header_line(ts)
    --    local prev_mod = vim.bo[buf].modifiable
    --    vim.bo[buf].modifiable = true
    --    local lc = vim.api.nvim_buf_line_count(buf)
    --    if lc == 0 then
    --        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { hdr })
    --    else
    --        vim.api.nvim_buf_set_lines(buf, 0, 1,  false, { hdr })
    --    end
    --    vim.bo[buf].modifiable = prev_mod
    --end

    -- function M.refresh_header(buf, ts)
    --     if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
    --     local hdr = build_header_lines(ts)

    --     local prev_mod = vim.bo[buf].modifiable
    --     vim.bo[buf].modifiable = true

    --     -- how many header lines are currently in the buffer?
    --     local n = tonumber(vim.b[buf].nicetstamp_hdr_n or 1) or 1
    --     local lc = vim.api.nvim_buf_line_count(buf)

    --     if lc == 0 then
    --         vim.api.nvim_buf_set_lines(buf, 0, -1, false, hdr)
    --     else
    --         local endi = math.min(n, lc)
    --         vim.api.nvim_buf_set_lines(buf, 0, endi, false, hdr)
    --     end

    --     -- store new header height
    --     vim.b[buf].nicetstamp_hdr_n = #hdr + (M.config.blank_after_header and 1 or 0)

    --     vim.bo[buf].modifiable = prev_mod
    -- end


    function M.refresh_header(buf, ts)
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
        local hdr = header.build_header_lines(ts)

        local prev_mod = vim.bo[buf].modifiable
        vim.bo[buf].modifiable = true

        -- how many header lines were previously written (default to current hdr size)
        local n_prev = tonumber(vim.b[buf].nicetstamp_hdr_n) or #hdr
        local lc = vim.api.nvim_buf_line_count(buf)

        if lc == 0 then
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, hdr)
        else
            local endi = math.min(n_prev, lc)  -- replace exactly previous header range
            vim.api.nvim_buf_set_lines(buf, 0, endi, false, hdr)
        end

        -- IMPORTANT: track ONLY header height (no blank separator)
        vim.b[buf].nicetstamp_hdr_n = #hdr

        vim.bo[buf].modifiable = prev_mod
    end

    ---@param buf integer
    ---@param ts number
    function M.set(buf, ts)
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
        if type(ts) ~= "number" then return end
        vim.b[buf].nicetstamp_ts = ts
        M.refresh_header(buf, ts)
    end

    ---@param buf integer
    ---@return number|nil
    function M.get(buf)
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then return nil end
        local v = vim.b[buf].nicetstamp_ts
        return (type(v) == "number") and v or nil
    end


    -----@param lines string|string[]
    -----@param ts number|nil
    -----@return string[]
    --function M.prepend_header(lines, ts)
    --    local out = to_lines(lines)
    --    table.insert(out, 1, header_line(ts))
    --    return out
    --end

    -----@param lines string|string[]
    -----@param ts number|nil
    -----@param opts { force_blank?: boolean }|nil  -- set force_blank=true to always add a blank line
    -----@return string[]
    --function M.prepend_header(lines, ts, opts)
    --    local body = to_lines(lines)
    --    local has_body = false
    --    -- consider there to be "body" if it's not empty and not just {""}
    --    if #body > 1 then
    --        has_body = true
    --    elseif #body == 1 and body[1] ~= "" then
    --        has_body = true
    --    end

    --    local out = { header_line(ts) }
    --    if (opts and opts.force_blank) or has_body then
    --        out[#out+1] = ""  -- the blank separator line
    --    end
    --    for i = 1, #body do
    --        out[#out+1] = body[i]
    --    end
    --    return out
    --end

    -- function M.prepend_header(lines, ts, opts)
    --     local body = to_lines(lines)
    --     local has_body = (#body > 1) or (#body == 1 and body[1] ~= "")
    --     local out = build_header_lines(ts)

    --     local force_blank = opts and opts.force_blank
    --     if force_blank or (M.config.blank_after_header and has_body) then
    --         out[#out+1] = ""
    --     end

    --     for i = 1, #body do out[#out+1] = body[i] end
    --     -- record header height for future refreshes
    --     vim.b[vim.api.nvim_get_current_buf()].nicetstamp_hdr_n = (#out - #body)
    --     return out
    -- end


    function M.prepend_header(lines, ts, opts)
        opts = opts or {}
        local body = header.to_lines(lines)
        local has_body = (#body > 1) or (#body == 1 and body[1] ~= "")

        local hdr = header.build_header_lines(ts)
        local out = {}
        for i = 1, #hdr do out[#out+1] = hdr[i] end

        local force_blank = opts.force_blank
        if force_blank or (config.blank_after_header and has_body) then
            out[#out+1] = ""
        end
        for i = 1, #body do out[#out+1] = body[i] end

        -- record ONLY header height on the **target** buffer
        local target_buf = opts.buf or vim.api.nvim_get_current_buf()
        if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
            vim.b[target_buf].nicetstamp_hdr_n = #hdr
        end

        return out
    end

    return M
end
