return function(context)
    local funcs = context.funcs
    local ts = context.ts
    local ts_boot = context.ts_boot
    local ts_group = context.group

    local ok_custom = ts_boot.register_custom_parsers()
    if not ok_custom then
        funcs.safe_notify("treesitter: custom parser registration failed", vim.log.levels.WARN)
    end

    vim.api.nvim_create_autocmd("User", {
        group = ts_group,
        pattern = "TSUpdate",
        callback = function()
            ts_boot.register_custom_parsers()
        end,
    })

    ts.install({
        "html",
        "css",
        "bash",
        "sql",
        "latex",
        "python",
        "javascript",
        "typescript",
        "swift",
        "c",
        "lua",
        "vim",
        "vimdoc",
        "query",
        "json",
        "xml",
        "yaml",
        "http",
        "mermaid",
        "dot",

        -- "norg",
        -- "norg_meta",
    })
end
