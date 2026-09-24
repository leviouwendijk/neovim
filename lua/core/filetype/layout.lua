local M = {}

M.priority = {
    stats = 100,
    date = 200,
    permission = 300,
    warning = 400,
}

local default_gap = 3
local default_cap_fraction = 0.40

local function display_width(text)
    return vim.fn.strdisplaywidth(text or "")
end

local function chunk_width(chunk)
    return display_width(chunk.text)
end

local function normalized_budget(value)
    return math.max(
        0,
        math.floor(tonumber(value) or 0)
    )
end

function M.metadata_budget(options)
    options = options or {}

    local window_width =
        normalized_budget(options.window_width)
    local textoff =
        normalized_budget(options.textoff)
    local text_width =
        math.max(0, window_width - textoff)

    local gap =
        normalized_budget(
            options.gap == nil
                and default_gap
                or options.gap
        )

    local cap_fraction =
        tonumber(options.cap_fraction)
        or default_cap_fraction

    cap_fraction =
        math.max(0, math.min(1, cap_fraction))

    local line_width =
        display_width(options.line or "")
    local free_width =
        math.max(
            0,
            text_width - line_width - gap
        )
    local capped_width =
        math.floor(text_width * cap_fraction)

    return math.min(
        free_width,
        capped_width
    )
end

function M.window_budget(win, line)
    local window_width =
        vim.api.nvim_win_get_width(win)
    local info =
        vim.fn.getwininfo(win)[1]
        or {}

    return M.metadata_budget({
        window_width = window_width,
        textoff = info.textoff or 0,
        line = line,
    })
end

function M.fit(chunks, budget)
    budget = normalized_budget(budget)

    if budget == 0 or #chunks == 0 then
        return {}
    end

    local candidates = {}
    local widths = {}

    for index, chunk in ipairs(chunks) do
        local width = chunk_width(chunk)
        widths[index] = width

        table.insert(candidates, {
            index = index,
            priority = chunk.priority or 0,
            width = width,
        })
    end

    table.sort(candidates, function(lhs, rhs)
        if lhs.priority == rhs.priority then
            return lhs.index < rhs.index
        end

        return lhs.priority > rhs.priority
    end)

    local selected = {}
    local used = 0
    local omitted_stats = 0
    local last_stats_index = 0

    for index, chunk in ipairs(chunks) do
        if chunk.group == "stats" then
            last_stats_index = index
        end
    end

    for _, candidate in ipairs(candidates) do
        local chunk = chunks[candidate.index]

        if used + candidate.width <= budget then
            selected[candidate.index] = true
            used = used + candidate.width
        elseif chunk.group == "stats" then
            omitted_stats = omitted_stats + 1
        end
    end

    local overflow = nil

    if omitted_stats > 0 then
        local function overflow_chunk()
            local value = {
                text = string.format(
                    "+%d ",
                    omitted_stats
                ),
                highlight = "Comment",
            }

            return value, chunk_width(value)
        end

        local marker, marker_width =
            overflow_chunk()

        while used + marker_width > budget do
            local remove_index = nil

            for index = #chunks, 1, -1 do
                if
                    selected[index]
                    and chunks[index].group == "stats"
                then
                    remove_index = index
                    break
                end
            end

            if not remove_index then
                break
            end

            selected[remove_index] = nil
            used = used - widths[remove_index]
            omitted_stats = omitted_stats + 1
            marker, marker_width =
                overflow_chunk()
        end

        if used + marker_width <= budget then
            overflow = marker
        end
    end

    local fitted = {}

    for index, chunk in ipairs(chunks) do
        if selected[index] then
            table.insert(fitted, {
                chunk.text,
                chunk.highlight,
            })
        end

        if
            overflow
            and index == last_stats_index
        then
            table.insert(fitted, {
                overflow.text,
                overflow.highlight,
            })
        end
    end

    return fitted
end

return M
