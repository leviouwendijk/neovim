local testing = require("testing")
local expect = testing.expect

return testing.suite("startup", {
    testing.test(
        "production_config_boots_headless",
        function()
            local root = vim.g.nvim_config_test_root
            local init = vim.fs.joinpath(root, "init.lua")

            local verify = [[
lua if vim.v.errmsg ~= "" then
    io.stderr:write(vim.v.errmsg .. "\n")
    vim.cmd("cquit 1")
end

local required_commands = {
    "CheckDeps",
    "IndentNone",
    "ShellHere",
    "SetLSP",
}

for _, command in ipairs(required_commands) do
    if vim.fn.exists(":" .. command) ~= 2 then
        io.stderr:write(
            "missing production command: "
                .. command
                .. "\n"
        )
        vim.cmd("cquit 1")
    end
end

local required_integrations = {
    "integrations.harpoon",
    "integrations.lsp",
    "integrations.lsp.ltex",
    "integrations.luasnip",
    "integrations.treesitter",
    "integrations.treesitter.context",
    "interface.checkhealth",
    "interface.colorscheme",
    "interface.statusline",
}

for _, integration in ipairs(required_integrations) do
    if package.loaded[integration] == nil then
        io.stderr:write(
            "missing production integration: "
                .. integration
                .. "\n"
        )
        vim.cmd("cquit 1")
    end
end
]]

            local result = vim.system({
                vim.v.progpath,
                "--headless",
                "-u",
                init,
                "--cmd",
                "let v:errmsg = ''",
                "-c",
                verify,
                "-c",
                "qa!",
            }, {
                text = true,
            }):wait(10000)

            expect.equal(
                result.code,
                0,
                "production startup failed: "
                    .. tostring(result.stderr or "")
            )
        end
    ),
}, {
    title = "Startup",
})
