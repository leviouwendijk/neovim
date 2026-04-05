local funcs = require("config.funcs")

local ts = funcs.require_or_nil("nvim-treesitter", {
    message = "nvim-treesitter missing; skipping setup",
})
local ts_boot = funcs.require_or_nil("core.treesitter", {
    message = "core.treesitter missing; skipping custom parser setup",
})

if not ts or not ts_boot then
    return
end

local ts_group = vim.api.nvim_create_augroup("LeviTreesitter", { clear = true })

ts.setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
})

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
})

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
