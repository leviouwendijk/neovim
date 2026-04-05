-- lua/extensions/bedrocks.lua
-- Ask Bedrocks about current code (selection or entire buffer), with --json envelope parsing
-- and a plain-text boxed header (uses extensions/nice_header.lua).

local M = {}

local Header = require("extensions.niceheader")
local acc = require("accessor")
local funcs = require("config.funcs")

-- === USER SETTINGS ===
local cfg = {
    bin = acc.bin.bedrocks,
    subcommand = "stream",              -- or "converse"
    extra_args = { },                   -- e.g. { "--latency=standard" }
    title = "Bedrocks",
    system_hint = nil,                  -- optional static system hint for prompt builder
    max_bytes = 200000,                 -- safety cap
    header = {
        style     = "boxed",              -- "boxed" | "double" | "minimal"
        max_width = nil,                  -- nil = autosize to float width
        padding_l = 1,
        padding_r = 1,
        align     = "left",
    },
}

-- === small utils ===
local function get_visual_selection_or_buffer()
    local mode = vim.fn.mode()
    local lines
    if mode:match("[vV\22]") then
        local _, ls, cs, _ = unpack(vim.fn.getpos("v"))
        local _, le, ce, _ = unpack(vim.fn.getpos("."))
        if ls > le or (ls == le and cs > ce) then
            ls, le = le, ls; cs, ce = ce, cs
        end
        lines = vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
        else
        lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end
    local text = table.concat(lines, "\n")
    if #text > cfg.max_bytes then
        text = text:sub(1, cfg.max_bytes) .. "\n\n…[truncated]…"
        end
    return text, mode:match("[vV\22]") ~= nil
end

local function fenced(block, ft)
    ft = ft or vim.bo.filetype or ""
    return ("```%s\n%s\n```"):format(ft, block)
end

local function build_prompt(user_question, code_text)
    local path = vim.fn.expand("%:p")
    local ft = vim.bo.filetype or ""
    local pieces = {}
    if cfg.system_hint then
        table.insert(pieces, ("[SYSTEM]\n%s\n\n"):format(cfg.system_hint))
    end
    table.insert(pieces, ("[FILE]\npath: %s\nfiletype: %s\n\n"):format(path, ft))
    table.insert(pieces, "[QUESTION]\n" .. user_question .. "\n\n")
    table.insert(pieces, "[CODE]\n" .. fenced(code_text, ft) .. "\n")
    return table.concat(pieces, "")
end

local function open_float()
    local width  = math.floor(vim.o.columns * 0.82)
    local height = math.floor(vim.o.lines * 0.66)
    local row    = math.floor((vim.o.lines - height) / 5)
    local col    = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown" -- body shows as md; header is plain text lines

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        title = cfg.title,
        title_pos = "center",
    })
    return buf, win, width
end

-- local function run_bedrocks(prompt_text, on_done)
--     local args = { cfg.subcommand, "--json" }
--     for _, a in ipairs(cfg.extra_args) do table.insert(args, a) end
--     vim.system(
--         vim.list_extend({ cfg.bin }, args),
--         { stdin = prompt_text, text = true },
--         function(res)
--             local out  = res.stdout or ""
--             local err  = res.stderr or ""
--             local code = res.code or 0
--             if (out == "" or not out) and code ~= 0 then
--                 on_done(err, code)
--             else
--                 on_done(out, code)
--             end
--         end
--     )
-- end

local function run_bedrocks(prompt_text, on_done)
    local args = { cfg.subcommand, "--json" }
    for _, a in ipairs(cfg.extra_args) do
        table.insert(args, a)
    end

    local ok_bin, bin = funcs.has_executable(cfg.bin)
    if not ok_bin then
        funcs.safe_notify("bedrocks helper is unavailable", vim.log.levels.WARN)
        on_done("bedrocks helper is unavailable", 127)
        return
    end

    vim.system(
        vim.list_extend({ bin }, args),
        { stdin = prompt_text, text = true },
        function(res)
            local out  = res.stdout or ""
            local err  = res.stderr or ""
            local code = res.code or 0

            if (out == "" or not out) and code ~= 0 then
                on_done(err, code)
            else
                on_done(out, code)
            end
        end
    )
end

local function safe_guard_sensitive()
    local bad = { ".env", ".pem", ".key", ".rsa", ".crt", ".p12" }
    local name = vim.fn.expand("%:t")
    for _, ext in ipairs(bad) do
        if name:sub(-#ext) == ext then
            return false, ("Refusing to send potentially sensitive file (%s)."):format(ext)
        end
    end
    return true
end

-- naive ISO8601 → epoch (seconds)
local function iso_to_epoch(ts)
    if not ts then return nil end
    local y, m, d, H, M, S = ts:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
    if not y then return nil end
    return os.time({
        year = tonumber(y), month = tonumber(m), day = tonumber(d),
        hour = tonumber(H), min = tonumber(M), sec = tonumber(S),
    })
end

local function human_ago(epoch)
    if not epoch then return "just now" end
    local d = math.max(0, os.time() - epoch)
    if d < 2 then return "just now" end
    if d < 60 then return d .. "s ago" end
    if d < 3600 then return math.floor(d/60) .. "m ago" end
    if d < 86400 then return math.floor(d/3600) .. "h ago" end
    return math.floor(d/86400) .. "d ago"
end

local function try_decode_json(s)
    local ok, val = pcall(vim.json.decode, s, { luanil = { object = true, array = true } })
    if ok and type(val) == "table" then return val end
    return nil
end

local function build_header_text(env, was_snippet, code_bytes)
    local r   = env.result or {}
    local rq  = env.request or {}
    local inf = rq.inference or {}
    local inp = rq.inputs or {}
    local usage = r.usage or {}

    local model   = (r.modelId or inf.modelId) or "?"
    local region  = (r.region or inf.region) or "?"
    local stop    = r.stopReason or "?"
    local ts      = r.ts or ""
    local when    = human_ago(iso_to_epoch(ts))

    local inTok   = usage.inputTokens  and tostring(usage.inputTokens)  or "?"
    local outTok  = usage.outputTokens and tostring(usage.outputTokens) or "?"

    local filetype = inp.filetype or vim.bo.filetype or "?"
    local path     = inp.path or vim.fn.expand("%:p")
    local bytes    = inp.bytes or code_bytes
    local snippet  = (inp.snippet ~= nil) and inp.snippet or was_snippet
    local hmax     = (inf.historyMax ~= nil) and tostring(inf.historyMax) or "—"

    -- Deliberately structured across lines; nice_header will preserve breaks.
    local line1 = string.format("%s", cfg.title)
    local line2 = string.format("model: %s   •   region: %s", model, region)
    local line3 = string.format("stop: %s", stop)
    local line4 = string.format("tokens: %s/%s (in/out)   •   history: %s", inTok, outTok, hmax)
    local line5 = string.format("file: %s  (%s)", path, filetype)
    local line6 = string.format("snippet: %s   •   bytes: %s   •   %s", tostring(snippet), tostring(bytes), when)

    return table.concat({ line1, line2, line3, line4, line5, line6 }, "\n")
end

-- === user entrypoint ===
function M.ask_bedrocks()
    local ok, why = safe_guard_sensitive()
    if not ok then
        vim.notify(why or "Refusing to send potentially sensitive file.", vim.log.levels.WARN)
        return
    end

    vim.ui.input({ prompt = "Ask Bedrocks: " }, function(q)
        if not q or q == "" then return end

        local code, was_snippet = get_visual_selection_or_buffer()
        local prompt_text = build_prompt(q, code)

        local buf, win, float_w = open_float()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "sending to bedrocks…" })

        run_bedrocks(prompt_text, function(output, code_rc)
            vim.schedule(function()
                local env = try_decode_json(output or "")
                if not env then
                    -- fallback: raw text (no markdown in header)
                    local head_text = (code_rc ~= 0)
                        and ("bedrocks exit " .. tostring(code_rc))
                        or cfg.title
                    local header = Header.render(head_text, vim.tbl_deep_extend("force", cfg.header, {
                        max_width = float_w - 4, -- keep within box
                    }))
                    local body = vim.split(output or "", "\n", { plain = true })
                    -- local lines = vim.list_extend(header, { "", "" })
                    local lines = vim.list_extend(header, { "" })
                    lines = vim.list_extend(lines, body)
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

                    -- place cursor at first body line, clamped
                    local total = vim.api.nvim_buf_line_count(buf)
                    local target = math.max(1, math.min(total, #header + 3))
                    pcall(vim.api.nvim_win_set_cursor, win, { target, 0 })
                    return
                end

                local header_text = build_header_text(env, was_snippet, #code)
                local header = Header.render(header_text, vim.tbl_deep_extend("force", cfg.header, {
                    max_width = float_w - 4, -- try to fit nicely in the window
                }))

                local body_text = (env.result and env.result.response) or ""
                local body = (body_text == "") and { "(empty response)" }
                    or vim.split(body_text, "\n", { plain = true })

                -- local lines = vim.list_extend(header, { "", "" })
                local lines = vim.list_extend(header, { "" })
                lines = vim.list_extend(lines, body)

                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

                -- place cursor at first body line, clamped
                local total = vim.api.nvim_buf_line_count(buf)
                local target = math.max(1, math.min(total, #header + 3))
                pcall(vim.api.nvim_win_set_cursor, win, { target, 0 })
            end)
        end)
    end)
end

-- Keymaps / Commands
vim.keymap.set({ "n", "v" }, "<leader>ai", M.ask_bedrocks, { desc = "Ask Bedrocks (selection or buffer)" })
vim.api.nvim_create_user_command("BedrocksAsk", function() M.ask_bedrocks() end, {})

return M
