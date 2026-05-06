local M = {}
local acc = require("accessor")
local funcs = require("config.funcs")

function M.register_custom_parsers()
    local parsers = funcs.require_or_nil("nvim-treesitter.parsers", {
        message = "nvim-treesitter.parsers missing; skipping custom parser registration",
        silent = true,
    })

    if not parsers then
        return false
    end

    -- experimental syntaxes, unpublished
    -- parsers.dbml = {
    --     install_info = {
    --         path = vim.fn.expand("~/.local/share/nvim/tree-sitter-dbml"),
    --         -- queries = "queries",
    --     },
    --     filetype = "dbml",
    -- }

    -- parsers.sdia = {
    --     install_info = {
    --         path = vim.fn.expand("~/.local/share/nvim/tree-sitter-sdia"),
    --         -- queries = "queries",
    --     },
    --     filetype = "sdia",
    -- }

    parsers.ec = {
        install_info = {
            -- path = vim.fn.expand("~/.local/share/nvim/tree-sitter-ec"),
            --
            -- no longer local:
            url = acc.treesitter.ec.repo,
            branch = acc.treesitter.ec.branch,
            queries = "queries",
        },
        filetype = "ec",
    }

    parsers.norg = {
        install_info = {
            url = "https://github.com/nvim-neorg/tree-sitter-norg",
            branch = "main",
            files = { "src/parser.c", "src/scanner.cc" },
            cxx_standard = "c++14",
        },
        filetype = "norg",
    }

    parsers.norg_meta = {
        install_info = {
            url = "https://github.com/nvim-neorg/tree-sitter-norg-meta",
            branch = "main",
            files = { "src/parser.c" },
        },
    }

    vim.filetype.add({
        extension = {
            functions = "zsh",
            aliases = "zsh",
            dbml = "dbml",
            sdia = "sdia",
            ec = "ec",
            norg = "norg",
        },
    })

    vim.treesitter.language.register("bash", { "sh", "zsh" })
    vim.treesitter.language.register("latex", { "tex" })
    vim.treesitter.language.register("dbml", { "dbml" })
    vim.treesitter.language.register("sdia", { "sdia" })
    vim.treesitter.language.register("ec", { "ec" })
    vim.treesitter.language.register("norg", { "norg" })

    return true
end

return M
