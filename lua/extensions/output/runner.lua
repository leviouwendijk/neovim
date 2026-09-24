return function(context)
    local state = context.state
    local split = context.split
    local float = context.float
    local M = {}

    -- ========== runner ==========

    local function capture_command(cmd, file)
        local ok, result = pcall(vim.fn.systemlist, { cmd, file })
        local out = {}
        if not ok then
            out = { "Failed to run: " .. tostring(cmd) .. " " .. tostring(file) }
            return out, 1
        end
        out = result or {}
        local code = vim.v.shell_error or 0
        return out, code
    end

    -- opts: { cmd, file, lines, mode="split"|"float", float={width,height,title,filetype,border} }
    function M.run(opts)
        if not opts or not opts.cmd then
            vim.notify("output.run: missing opts.cmd", vim.log.levels.ERROR)
            return
        end

        local file = opts.file or vim.fn.expand("%:p")
        local lines_pad = opts.lines or 0
        local mode = opts.mode or state.config.default_mode

        local lead = {}
        for _ = 1, lines_pad do table.insert(lead, "") end

        local out, code = capture_command(opts.cmd, file)
        if code ~= 0 then table.insert(out, string.format("[exit %d]", code)) end
        for i = #lead, 1, -1 do table.insert(out, 1, lead[i]) end

        if mode == "float" then
            if opts.float then
                state.config.float = vim.tbl_deep_extend("force", state.config.float, opts.float)
            end
            float.write(out)
        else
            split.write(out)
        end
    end

    return M
end
