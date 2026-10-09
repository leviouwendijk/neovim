local testing = require("testing")
local expect = testing.expect
local setup = require("integrations.lsp.semantics")

return testing.suite("semantics_lsp", {
    testing.test("disabled_by_default", function()
        setup({
            acc = { swiftsemantics = { lsp = { enabled = false } } },
            funcs = {
                has_executable = function()
                    error("Disabled integration must not probe the binary")
                end,
            },
        })
    end),
    testing.test("missing_binary_is_nonfatal", function()
        local warned = false
        setup({
            acc = {
                swiftsemantics = { lsp = { enabled = true } },
                bin = { semlsp = { production = { "semlsp" } } },
            },
            funcs = {
                has_executable = function() return false end,
                warn_once = function()
                    warned = true
                end,
            },
        })
        expect.equal(warned, true, "missing semlsp warns instead of breaking startup")
    end),
    testing.test("available_binary_registers_separate_swift_server", function()
        local prior_config, prior_enable = vim.lsp.config, vim.lsp.enable
        local name, options, enabled
        local ok, err = pcall(function()
            rawset(vim.lsp, "config", function(server, config)
                name, options = server, config
            end)
            rawset(vim.lsp, "enable", function(server)
                enabled = server
            end)
            setup({
                acc = {
                    swiftsemantics = { lsp = { enabled = true } },
                    bin = { semlsp = { production = { "semlsp" } } },
                },
                funcs = {
                    has_executable = function() return true end,
                },
            })
        end)
        rawset(vim.lsp, "config", prior_config)
        rawset(vim.lsp, "enable", prior_enable)
        if not ok then error(err, 0) end
        options = assert(options, "registered semlsp configuration")
        expect.equal(name, "semlsp", "independent server name")
        expect.equal(enabled, "semlsp", "enabled server name")
        expect.equal(options.filetypes[1], "swift", "Swift-only attachment")
        expect.equal(options.offset_encoding, "utf-16", "position encoding")
        expect.equal(options.cmd[1], "semlsp", "configured executable")
    end),
}, { title = "SwiftSemantics LSP" })
