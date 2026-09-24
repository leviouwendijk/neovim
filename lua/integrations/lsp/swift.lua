return function(context)
    local funcs = context.funcs

    vim.g.swift_auto_format_on_save = false

    -- Per-buffer toggle: :SwiftFormatOnSave [on|off|toggle]
    vim.api.nvim_create_user_command('SwiftFormatOnSave', function(opts)
        local arg = (opts.fargs[1] or 'toggle'):lower()
        local cur = (vim.b.swift_auto_format_on_save ~= nil)
        and vim.b.swift_auto_format_on_save
        or vim.g.swift_auto_format_on_save
        local val
        if arg == 'on' or arg == 'enable' then val = true
        elseif arg == 'off' or arg == 'disable' then val = false
        elseif arg == 'toggle' then val = not cur
        else
            print("Usage: :SwiftFormatOnSave [on|off|toggle]")
            return
        end
        vim.b.swift_auto_format_on_save = val
        funcs.safe_notify("Swift format-on-save: " .. (val and "ON" or "OFF"))
    end, { nargs = '?' })

    -- Optional global toggle: :SwiftFormatOnSaveGlobal [on|off|toggle]
    vim.api.nvim_create_user_command('SwiftFormatOnSaveGlobal', function(opts)
        local arg = (opts.fargs[1] or 'toggle'):lower()
        local val
        if arg == 'on' or arg == 'enable' then val = true
        elseif arg == 'off' or arg == 'disable' then val = false
        elseif arg == 'toggle' then val = not vim.g.swift_auto_format_on_save
        else
            print("Usage: :SwiftFormatOnSaveGlobal [on|off|toggle]")
            return
        end
        vim.g.swift_auto_format_on_save = val
        funcs.safe_notify("Swift format-on-save (global default): " .. (val and "ON" or "OFF"))
    end, { nargs = '?' })

    local function _swift_attach_formatting(_, bufnr)
        -- Make LSP do range formatting for gq (motions/visual)
        vim.bo[bufnr].formatexpr = 'v:lua.vim.lsp.formatexpr()'

        -- Format on save (guarded by per-buffer OR global boolean)
        vim.api.nvim_create_autocmd('BufWritePre', {
            buffer = bufnr,
            callback = function()
                local b = vim.b.swift_auto_format_on_save
                local g = vim.g.swift_auto_format_on_save
                if b == false or (b == nil and g == false) then return end
                vim.lsp.buf.format({ async = false })
            end,
        })

        -- Normal: '==' formats WHOLE file (Swift buffer only)
        vim.keymap.set('n', '==', function()
            vim.lsp.buf.format({ async = false })
        end, { buffer = bufnr, silent = true })

        -- Visual: '=' formats ONLY THE SELECTION
        vim.keymap.set('x', '=', function()
            local s = vim.api.nvim_buf_get_mark(0, '<') -- {line, col}
            local e = vim.api.nvim_buf_get_mark(0, '>') -- {line, col}
            vim.lsp.buf.format({
                async = false,
                range = {
                    ['start'] = { s[1] - 1, s[2] },
                    ['end']   = { e[1] - 1, e[2] },
                },
            })
        end, { buffer = bufnr, silent = true })
    end

    return _swift_attach_formatting
end
