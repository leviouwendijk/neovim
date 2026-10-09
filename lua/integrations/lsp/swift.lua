-- SourceKit formatting remains independent of external formatters.
return function(context)
    local funcs = context.funcs
    if vim.g.swift_auto_format_on_save == nil then
        vim.g.swift_auto_format_on_save = false
    end

    local function format_enabled(bufnr)
        local local_value = vim.b[bufnr].swift_auto_format_on_save
        if local_value ~= nil then return local_value == true end
        return vim.g.swift_auto_format_on_save == true
    end

    local function format_sourcekit(bufnr, range)
        vim.lsp.buf.format({
            bufnr = bufnr,
            async = false,
            range = range,
            filter = function(client)
                return client.name == "sourcekit"
            end,
        })
    end

    vim.api.nvim_create_user_command("SwiftFormatOnSave", function(opts)
        local arg = (opts.fargs[1] or "toggle"):lower()
        local current = format_enabled(vim.api.nvim_get_current_buf())
        local value
        if arg == "on" or arg == "enable" then value = true
        elseif arg == "off" or arg == "disable" then value = false
        elseif arg == "toggle" then value = not current
        else
            funcs.safe_notify(
                "Usage: :SwiftFormatOnSave [on|off|toggle]",
                vim.log.levels.WARN
            )
            return
        end
        vim.b.swift_auto_format_on_save = value
        funcs.safe_notify("Swift format-on-save: " .. (value and "ON" or "OFF"))
    end, { nargs = "?" })

    vim.api.nvim_create_user_command("SwiftFormatOnSaveGlobal", function(opts)
        local arg = (opts.fargs[1] or "toggle"):lower()
        local value
        if arg == "on" or arg == "enable" then value = true
        elseif arg == "off" or arg == "disable" then value = false
        elseif arg == "toggle" then
            value = not (vim.g.swift_auto_format_on_save == true)
        else
            funcs.safe_notify(
                "Usage: :SwiftFormatOnSaveGlobal [on|off|toggle]",
                vim.log.levels.WARN
            )
            return
        end
        vim.g.swift_auto_format_on_save = value
        funcs.safe_notify(
            "Swift format-on-save (global): " .. (value and "ON" or "OFF")
        )
    end, { nargs = "?" })

    local group = vim.api.nvim_create_augroup(
        "nvim_swift_format_on_save", { clear = true }
    )

    local function attach(_, bufnr)
        vim.bo[bufnr].formatexpr = "v:lua.vim.lsp.formatexpr()"

        -- Clear only this buffer's prior formatter callback on reattach.
        vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
            group = group,
            buffer = bufnr,
            callback = function()
                if format_enabled(bufnr) then
                    format_sourcekit(bufnr)
                end
            end,
        })

        vim.keymap.set("n", "==", function()
            format_sourcekit(bufnr)
        end, { buffer = bufnr, silent = true })

        vim.keymap.set("x", "=", function()
            local first = vim.api.nvim_buf_get_mark(bufnr, "<")
            local last = vim.api.nvim_buf_get_mark(bufnr, ">")
            format_sourcekit(bufnr, {
                ["start"] = { first[1] - 1, first[2] },
                ["end"] = { last[1] - 1, last[2] },
            })
        end, { buffer = bufnr, silent = true })
    end

    return attach
end

