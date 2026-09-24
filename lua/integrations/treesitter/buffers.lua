return function(context)
    local funcs = context.funcs
    local ts_group = context.group

    local highlight_filetypes = {
        html = true,
        css = true,
        sh = true,
        bash = true,
        sql = true,
        tex = true,
        python = true,
        javascript = true,
        typescript = true,
        swift = true,
        c = true,
        lua = true,
        vim = true,
        query = true,
        json = true,
        xml = true,
        yaml = true,
        http = true,
        mermaid = true,
        dot = true,
        dbml = true,
        sdia = true,
        ec = true,

        -- norg = true,
    }

    local indent_filetypes = {
        html = true,
        css = true,
        sh = true,
        bash = true,
        sql = true,
        tex = true,
        python = true,
        javascript = true,
        typescript = true,
        c = true,
        lua = true,
        vim = true,
        query = true,
        json = true,
        xml = true,
        yaml = true,
        http = true,
        mermaid = true,
        dot = true,
        dbml = true,
        sdia = true,

        -- norg = true,
    }

    vim.api.nvim_create_autocmd("FileType", {
        group = ts_group,
        pattern = "*",
        callback = function(ev)
            local ft = vim.bo[ev.buf].filetype
            if not highlight_filetypes[ft] then
                return
            end

            local lang = vim.treesitter.language.get_lang(ft) or ft

            local ok_add, err_add = vim.treesitter.language.add(lang)
            if not ok_add then
                funcs.safe_notify(
                    ("Tree-sitter language.add failed for ft=%s lang=%s: %s")
                        :format(ft, lang, tostring(err_add)),
                    vim.log.levels.ERROR
                )
                return
            end

            local ok_start, err_start = xpcall(function()
                vim.treesitter.start(ev.buf, lang)
            end, debug.traceback)

            if not ok_start then
                funcs.safe_notify(
                    ("Tree-sitter start failed for ft=%s lang=%s\n%s")
                        :format(ft, lang, tostring(err_start)),
                    vim.log.levels.ERROR
                )
            end
        end,
    })

    vim.api.nvim_create_autocmd("FileType", {
        group = ts_group,
        pattern = "*",
        callback = function(ev)
            local ft = vim.bo[ev.buf].filetype
            if not indent_filetypes[ft] then
                return
            end
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
    })

    -- vim.api.nvim_set_hl(0, "@function.ec", { fg = "#004096" })
    -- vim.api.nvim_set_hl(0, "@keyword.ec", { fg = "#9A47DD" })
    -- vim.api.nvim_set_hl(0, "@constant.ec", { fg = "#D7875F", bold = true })
    -- vim.api.nvim_set_hl(0, "@constant.builtin.ec", { fg = "#FF8800", bold = true })
    -- vim.api.nvim_set_hl(0, "@constant.special.ec", { fg = "#D70000", bold = true })
    -- vim.api.nvim_set_hl(0, "@function.builtin.ec", { fg = "#777777", bold = true })
    -- vim.api.nvim_set_hl(0, "@operator.ec", { fg = "#A1A1A1", bold = true })
    -- vim.api.nvim_set_hl(0, "@number.ec", { fg = "#D75F00" })
    -- vim.api.nvim_set_hl(0, "@string.ec", { fg = "#90A656" })
    -- vim.api.nvim_set_hl(0, "@comment.ec", { fg = "#9e9e9e", italic = true })
end
