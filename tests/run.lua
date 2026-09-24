local testing = require("testing")
local Loader = require("boot.loader")

local root = vim.g.nvim_config_test_root
if not root then
    local source = debug.getinfo(1, "S").source
    local path = source:sub(1, 1) == "@" and source:sub(2) or source
    root = vim.fn.fnamemodify(path, ":p:h:h")
    vim.g.nvim_config_test_root = root
    vim.opt.runtimepath:prepend(root)
end

local imports = dofile(
    vim.fs.joinpath(root, "tests", "imports.lua")
)
local selections = dofile(
    vim.fs.joinpath(root, "tests", "selections.lua")
)

local loader = Loader.new({
    imports = imports,
    order = {
        "suites",
    },
    strict = true,
    notify = function(message, level)
        vim.notify(message, level)
    end,
    load = function(path)
        return dofile(vim.fs.joinpath(root, path))
    end,
})

loader:process(selections.all)

local suite = testing.suite(
    "nvim",
    loader:values("suites"),
    {
        title = "Neovim tests",
    }
)

local reporter = testing.reporter.new({
    ansi = true,
})

local result = testing.runner.run(suite, {
    sink = reporter,
})

if result.is_failure then
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
