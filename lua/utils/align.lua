-- lua/utils/align.lua
local Align = {}

-- default settings
local DEFAULT_MIN_GAP = 2
local DEFAULT_OPERATORS = { "==", "<=", ">=", "=>", ":=", "->", "::", "=", ":", ";", "," }

local function trim_left(s)  return (s:gsub("^%s+", "")) end
local function trim_right(s) return (s:gsub("%s+$", "")) end

-- Sort operators longest-first so "==" wins over "="
local function normalize_ops(ops)
    ops = ops or DEFAULT_OPERATORS
    table.sort(ops, function(a,b) return #a > #b end)
    return ops
end

-- Try to split a (content) line into left/op/right for any of the operators.
-- Returns nil if no operator is found.
local function split_by_ops(core, ops)
    for _, op in ipairs(ops) do
        local i, j = core:find(op, 1, true) -- plain search
        if i then
            local left  = trim_right(core:sub(1, i - 1))
            local right = trim_left(core:sub(j + 1))
            return left, op, right
        end
    end
    return nil
end

-- Align a list of lines. Each item is a raw buffer line string.
-- Returns a new list of lines.
local function align_lines(lines, opts)
    local ops               = normalize_ops(opts and opts.ops)
    local min_gap           = (opts and opts.min_gap) or DEFAULT_MIN_GAP
    local min_space_before  = (opts and opts.space_before_op) or 1

    -- Pass 1: measure
    local rows, max_left, max_op = {}, 0, 0
    for i, line in ipairs(lines) do
        local indent = line:match("^(%s*)") or ""
        local core   = line:sub(#indent + 1)
        local left, op, right = split_by_ops(core, ops)
        if left then
            if #left > max_left then max_left = #left end
            if #op   > max_op   then max_op   = #op   end
            rows[i] = { indent = indent, left = left, op = op, right = right, has_op = true }
        else
            rows[i] = { raw = line, has_op = false }
        end
    end

    -- Columns
    local op_col = max_left + min_space_before

    -- Pass 2: rebuild
    local out = {}
    for i, r in ipairs(rows) do
        if not r.has_op then
            out[i] = r.raw
        else
            local spaces_before_op = op_col - #r.left
            if spaces_before_op < min_space_before then spaces_before_op = min_space_before end
            local after_op_spaces  = (max_op - #r.op) + min_gap
            out[i] = table.concat({
                r.indent, r.left,
                string.rep(" ", spaces_before_op),
                r.op,
                string.rep(" ", after_op_spaces),
                r.right,
            })
        end
    end

    return out
end

-- Public: align the current visual/command range
function Align.align_range(range, opts)
    local s = range.line1
    local e = range.line2
    local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
    local new_lines = align_lines(lines, opts)
    vim.api.nvim_buf_set_lines(0, s - 1, e, false, new_lines)
end

-- Simple k=v arg parser for the user command:
--   :'<,'>AlignOps gap=3 ops="==,=,:"
local function parse_args(argstr)
    local opts = {}
    for k, v in argstr:gmatch("(%w+)%s*=%s*([^%s]+)") do
        if k == "gap" or k == "min_gap" then
            opts.min_gap = tonumber(v) or DEFAULT_MIN_GAP
        elseif k == "ops" then
            local list = {}
            for item in v:gsub("^%p", ""):gsub("%p$", ""):gmatch("[^,]+") do
                table.insert(list, item)
            end
            opts.ops = list
        elseif k == "before" or k == "leftpad" then
            opts.space_before_op = tonumber(v) or 0
        end
    end
    return opts
end

vim.api.nvim_create_user_command("AlignOps", function(cmd)
    Align.align_range(cmd, parse_args(cmd.args))
end, { range = true, nargs = "*" })

vim.keymap.set("v", "<leader>af", ":AlignOps<CR>", { silent = true, desc = "Align operators in selection" })

return Align
