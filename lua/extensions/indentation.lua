local M = {}

local ns = vim.api.nvim_create_namespace("indentation")
local mode = "none" -- "none" | "dotted" | "countdots" | "countabc"

local function buf_tabw(buf)
    local sw = vim.bo[buf].shiftwidth
    local ts = vim.bo[buf].tabstop
    return (sw and sw > 0) and sw or ts
end

local function visual_indent_cols(lnum)
    return vim.fn.indent(lnum)
end

local function block_with_fill(k, tabw, fill, endchar)
    local num = tostring(k)
    if #num >= tabw then
        return num:sub(#num - tabw + 1, #num)
    end

    local tail = ""
    if endchar then
        local fillcount = tabw - #num - 1
        if fillcount < 0 then fillcount = 0 end
        tail = string.rep(fill, fillcount) .. endchar
    else
        local fillcount = tabw - #num
        tail = string.rep(fill, fillcount)
    end

    return num .. tail
end

local function block_with_pattern(k, tabw, pattern)
    local num = tostring(k)
    if #num >= tabw then
        return num:sub(#num - tabw + 1, #num)
    end
    local rest = tabw - #num
    local rep  = ""
    if rest > 0 then
        rep = pattern:rep(math.ceil(rest / #pattern)):sub(1, rest)
    end
    return num .. rep
end

local function make_pattern(kind, blocks, tabw)
    if kind == "dotted" then
        return string.rep("·", blocks * tabw)

    elseif kind == "countdots" then
        -- e.g. tabw=4:  "1..."| "2..."| "3..."| ...
        local t = {}
        -- for k = 1, blocks do
        for k = 0, blocks -1 do
            table.insert(t, block_with_fill(k, tabw, ".", nil))
        end
        return table.concat(t)

    elseif kind == "countdotsend" then
        -- e.g. tabw=4:  "1..;"| "2..;"| "3..;"| ...
        local t = {}
        -- for k = 1, blocks do
        for k = 0, blocks -1 do
            table.insert(t, block_with_fill(k, tabw, ".", ";"))
        end
        return table.concat(t)

    elseif kind == "countabc" then
        -- e.g. tabw=4:  "1abc"| "2abc"| "3abc"| ... (truncated to fit)
        local t = {}
        -- for k = 1, blocks do
        for k = 0, blocks -1 do
            table.insert(t, block_with_pattern(k, tabw, "abc"))
        end
        return table.concat(t)
    end

    return ""
end


local function clear(buf) vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1) end

local function decorate(buf, win)
    if mode == "none" then return end
    local tw = buf_tabw(buf)

    local view = vim.fn.winsaveview()
    local leftcol = view.leftcol or 0

    local topline = vim.fn.line("w0", win)
    local botline = vim.fn.line("w$", win)

    for lnum = topline, botline do
        local cols = visual_indent_cols(lnum)
        if cols > 0 then
            -- keep overlay strictly left of the cursor on the active line in INSERT
            local is_insert = (vim.fn.mode() == "i")
            if is_insert and lnum == vim.fn.line(".") then
                local curcol0 = vim.fn.virtcol(".") - 1  -- 0-based visual column
                if curcol0 > 0 then
                    cols = math.min(cols, curcol0)
                end
            end

            local s
            if mode == "dotted" then
                s = string.rep("·", cols)
            elseif mode == "countdots" then
                local blocks = math.ceil(cols / tw)
                s = make_pattern("countdots", blocks, tw):sub(1, cols)
            elseif mode == "countdotsend" then
                local blocks = math.ceil(cols / tw)
                s = make_pattern("countdotsend", blocks, tw):sub(1, cols)
            elseif mode == "countabc" then
                local blocks = math.ceil(cols / tw)
                s = make_pattern("countabc", blocks, tw):sub(1, cols)
            end
            -- if s and #s > 0 then
            --     vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
            --         virt_text = { { s, "NonText" } },
            --         virt_text_pos = "overlay",
            --         -- virt_text_win_col = leftcol, -- ✅ this makes the indent track laterally!
            --         hl_mode = "combine",
            --     })
            -- end
            if s and #s > 0 then
                -- how much of the indent is scrolled off to the left
                local hidden = math.min(leftcol, cols)
                local visible = cols - hidden

                -- if the entire indent is off-screen, don't draw anything
                if visible > 0 then
                    -- only draw the visible part of the indent string
                    local s_visible = s:sub(hidden + 1, hidden + visible)

                    vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
                        virt_text = { { s_visible, "NonText" } },
                        virt_text_pos = "overlay",
                        virt_text_win_col = 0, -- start at left edge of the window
                        hl_mode = "combine",
                    })
                end
            end
        end
    end
end

local function refresh()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    clear(buf)
    decorate(buf, win)
end

function M.set(template)
    mode = template or "none"
    if mode == "dotted" then vim.opt.list = false end
    refresh()
end

function M.setup()
    local timer = nil

    local local_refresh = function()
        pcall(refresh)
    end

    local function safe_close(t)
        if not t then return end
        pcall(function() t:stop() end)
        pcall(function() t:close() end)
    end

    local function schedule_refresh()
        safe_close(timer)
        timer = nil

        timer = vim.loop.new_timer()
        if not timer or type(timer.start) ~= "function" then
            -- fallback: run immediate refresh if timer couldn't be created
            vim.schedule(local_refresh)
            return
        end

        local ok, _ = pcall(function()
            timer:start(5, 0, vim.schedule_wrap(function()
                safe_close(timer)
                timer = nil
                local_refresh()
            end))
        end)

        if not ok then
            safe_close(timer)
            timer = nil
            vim.schedule(local_refresh)
        end
    end

    vim.api.nvim_create_autocmd({
        "BufEnter",
        "WinScrolled",
        "CursorMoved",
        "OptionSet",
        "TextChanged",
        "TextChangedI",
        "CursorMovedI",
        "InsertCharPre",
    }, {
        callback = schedule_refresh,
    })
end

return M
