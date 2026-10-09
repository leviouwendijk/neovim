-- Incremental :S preview: highlight matches while searching, then render
-- bounded projected substitutions in-place and in the preview split.
-- Neovim rolls back preview-only buffer mutations on cancel/commit.
local parsing = require("utils.casecon-substitute-parse")

local MAX_PROJECTED_LINES = 24
local MAX_PROJECTED_BYTES = 12000
local MAX_HIGHLIGHTS = 300
local WAIT_MS = 120

return function(config)
    return function(opts, namespace, preview_buffer)
        -- Match native :s: open the preview split as soon as the
        -- first delimiter is entered, even before search text exists.
        local input = (opts.args or ""):gsub("^%s+", "")
        if #input == 1 and not input:match("[%w%s\\]") then
            if not preview_buffer then return 0 end
            vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, { "" })
            return 2
        end

        local spec = parsing.parse(opts.args, true)
        if not spec then return 0 end

        local source_buffer = vim.api.nvim_get_current_buf()
        local originals = vim.api.nvim_buf_get_lines(
            source_buffer, opts.line1 - 1, opts.line2, false
        )
        local candidates = {}
        local bytes, highlighted = 0, 0

        for index, line in ipairs(originals) do
            local matches = parsing.matches(line, spec.needle, spec.global)
            local absolute_line = opts.line1 + index - 1

            for _, match in ipairs(matches) do
                if highlighted >= MAX_HIGHLIGHTS then break end
                vim.api.nvim_buf_set_extmark(source_buffer, namespace,
                    absolute_line - 1, match[1], {
                        end_col = match[2],
                        hl_group = "Substitute",
                        priority = 200,
                    })
                highlighted = highlighted + 1
            end

            if #matches > 0
                and #candidates < MAX_PROJECTED_LINES
                and bytes + #line <= MAX_PROJECTED_BYTES then
                candidates[#candidates + 1] = {
                    line = absolute_line,
                    source = line,
                }
                bytes = bytes + #line
            end
        end

        -- Show original matching lines during search entry, without invoking Swift.
        if spec.stage == "search" then
            if not preview_buffer or #candidates == 0 then
                return highlighted > 0 and 1 or 0
            end

            local lines = {}
            for index, candidate in ipairs(candidates) do
                local prefix = ("%d | "):format(candidate.line)
                lines[index] = prefix .. candidate.source
            end
            vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, lines)

            for index, candidate in ipairs(candidates) do
                local prefix = ("%d | "):format(candidate.line)
                for _, match in ipairs(parsing.matches(candidate.source, spec.needle, true)) do
                    vim.api.nvim_buf_set_extmark(preview_buffer, namespace,
                        index - 1, #prefix + match[1], {
                            end_col = #prefix + match[2],
                            hl_group = "Substitute",
                        })
                end
            end

            return 2
        end

        if not preview_buffer or #candidates == 0
            or vim.fn.executable(config.bin) ~= 1 then
            return highlighted > 0 and 1 or 0
        end

        local command = {
            config.bin, "substitute", "--matching", spec.needle,
            "--replacement", spec.replacement, "--json",
        }
        if not spec.global then command[#command + 1] = "--first" end
        command[#command + 1] = "--"
        for _, candidate in ipairs(candidates) do
            command[#command + 1] = candidate.source
        end

        -- Preview is best-effort; a slow or unavailable CLI must never stall
        -- editing or prevent the final :S command from working.
        local ok, result = pcall(function()
            return vim.system(command, { text = true }):wait(WAIT_MS)
        end)
        if not ok or not result or result.code ~= 0 then
            return highlighted > 0 and 1 or 0
        end

        local decoded_ok, decoded = pcall(vim.json.decode, result.stdout or "")
        if not decoded_ok or type(decoded) ~= "table" or decoded.ok ~= true
            or type(decoded.result) ~= "table"
            or #decoded.result ~= #candidates then
            return highlighted > 0 and 1 or 0
        end

        local preview_lines = {}
        local prefixes = {}
        for index, candidate in ipairs(candidates) do
            local projected = decoded.result[index]
            if type(projected) ~= "string" then
                return highlighted > 0 and 1 or 0
            end
            local prefix = ("%d | "):format(candidate.line)
            prefixes[index] = #prefix
            preview_lines[index] = prefix .. projected
        end

        -- Preview changes are temporary: :command-preview restores the source
        -- buffer when command-line editing ends, including on cancellation.
        for index, candidate in ipairs(candidates) do
            local next_line = decoded.result[index]
            if next_line ~= candidate.source then
                vim.api.nvim_buf_set_lines(source_buffer,
                    candidate.line - 1, candidate.line, false, { next_line })
            end
        end

        vim.api.nvim_buf_set_lines(
            preview_buffer, 0, -1, false, preview_lines
        )
        for index, line in ipairs(preview_lines) do
            local prefix = prefixes[index]
            if #line > prefix then
                vim.api.nvim_buf_set_extmark(preview_buffer, namespace,
                    index - 1, prefix, {
                        end_col = #line,
                        hl_group = "Substitute",
                    })
            end
        end
        return 2
    end
end
