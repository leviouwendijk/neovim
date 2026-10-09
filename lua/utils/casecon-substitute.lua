-- Case-preserving literal substitution backed by the casecon Swift CLI.
return function(config, notify)
    local function parse(spec)
        local delimiter = spec:sub(1, 1)
        if delimiter == "" or delimiter:match("[%w%s]") then
            return nil, "expected /needle/replacement/[g]"
        end

        local function read_segment(position)
            local result = {}
            while position <= #spec do
                local char = spec:sub(position, position)
                if char == "\\" and position < #spec then
                    local following = spec:sub(position + 1, position + 1)
                    if following == delimiter or following == "\\" then
                        result[#result + 1] = following
                        position = position + 2
                    else
                        result[#result + 1] = char
                        position = position + 1
                    end
                elseif char == delimiter then
                    return table.concat(result), position + 1
                else
                    result[#result + 1] = char
                    position = position + 1
                end
            end
            return nil
        end

        local needle, next_position = read_segment(2)
        if not needle or needle == "" then
            return nil, "nonempty search text is required"
        end
        local replacement, flags_position = read_segment(next_position)
        if replacement == nil then
            return nil, "missing closing delimiter"
        end
        local flags = vim.trim(spec:sub(flags_position))
        if flags ~= "" and flags ~= "g" then
            return nil, "only the g flag is supported"
        end
        return { needle = needle, replacement = replacement, global = flags == "g" }
    end

    local function substitute(opts)
        if vim.fn.executable(config.bin) ~= 1 then
            notify.error("casecon executable not found: " .. config.bin)
            return
        end
        local spec, err = parse(vim.trim(opts.args))
        if not spec then
            notify.error("casecon: " .. err)
            return
        end

        local buffer = vim.api.nvim_get_current_buf()
        local original = vim.api.nvim_buf_get_lines(buffer, opts.line1 - 1, opts.line2, false)
        local updated = vim.deepcopy(original)
        local cursor, changed = 1, 0

        while cursor <= #original do
            local command = {
                config.bin, "substitute", "--matching", spec.needle,
                "--replacement", spec.replacement, "--json",
            }
            if not spec.global then command[#command + 1] = "--first" end
            command[#command + 1] = "--"

            local positions, bytes = {}, 0
            while cursor <= #original and #positions < 64 do
                local line = original[cursor]
                if line == "" then
                    cursor = cursor + 1
                elseif #positions > 0 and bytes + #line > 48000 then
                    break
                else
                    positions[#positions + 1] = cursor
                    command[#command + 1] = line
                    bytes = bytes + #line
                    cursor = cursor + 1
                end
            end

            if #positions > 0 then
                local result = vim.system(command, { text = true }):wait()
                if result.code ~= 0 then
                    notify.error("casecon substitute failed: " .. (result.stderr or "unknown error"))
                    return
                end
                local ok, decoded = pcall(vim.json.decode, result.stdout or "")
                if not ok or type(decoded) ~= "table" or decoded.ok ~= true
                    or type(decoded.result) ~= "table" or #decoded.result ~= #positions then
                    notify.error("casecon returned an invalid JSON response")
                    return
                end

                for index, position in ipairs(positions) do
                    local value = decoded.result[index]
                    if type(value) ~= "string" then
                        notify.error("casecon returned a non-string result")
                        return
                    end
                    if value ~= original[position] then changed = changed + 1 end
                    updated[position] = value
                end
            end
        end

        if changed == 0 then
            notify.info("casecon: no changes")
            return
        end
        -- One atomic buffer mutation after all subprocesses succeeded.
        vim.api.nvim_buf_set_lines(buffer, opts.line1 - 1, opts.line2, false, updated)
        notify.info(("casecon: modified %d line(s)"):format(changed))
    end

    vim.api.nvim_create_user_command("S", substitute, {
        nargs = 1,
        range = true,
        desc = "Literal case-preserving substitution via casecon",
    })

    vim.keymap.set("n", "<leader>cs", ":%S/", {
        desc = "Case-preserving substitution in buffer",
    })
    vim.keymap.set("x", "<leader>cs", ":S/", {
        desc = "Case-preserving substitution in selected lines",
    })
end
