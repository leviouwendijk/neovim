local testing = require("testing")
local expect = testing.expect

local function with_buffer(callback)
    local original = vim.api.nvim_get_current_buf()
    local buffer = vim.api.nvim_create_buf(false, true)
    local ok, err = pcall(function()
        vim.api.nvim_set_current_buf(buffer)
        callback(buffer)
    end)
    vim.api.nvim_set_current_buf(original)
    vim.api.nvim_buf_delete(buffer, { force = true })
    if not ok then error(err, 0) end
end

local function swift_setup()
    return require("integrations.lsp.swift")({
        funcs = { safe_notify = function() end },
    })
end

return testing.suite("lsp_tooling", {
    testing.test("swift_buffer_off_overrides_global_on", function()
        local original = vim.g.swift_auto_format_on_save
        local original_format = vim.lsp.buf.format
        local calls = 0
        local ok, err = pcall(function()
            vim.g.swift_auto_format_on_save = true
            rawset(vim.lsp.buf, "format", function() calls = calls + 1 end)
            with_buffer(function(bufnr)
                local attach = swift_setup()
                attach(nil, bufnr)
                vim.cmd("SwiftFormatOnSave off")
                vim.api.nvim_exec_autocmds("BufWritePre", { buffer = bufnr })
                expect.equal(calls, 0, "buffer-local false must override global true")
                vim.cmd("SwiftFormatOnSave toggle")
                vim.api.nvim_exec_autocmds("BufWritePre", { buffer = bufnr })
                expect.equal(calls, 1, "buffer-local toggle must turn formatting on")
            end)
        end)
        rawset(vim.lsp.buf, "format", original_format)
        vim.g.swift_auto_format_on_save = original
        if not ok then error(err, 0) end
    end),
    testing.test("swift_repeated_attach_is_idempotent", function()
        with_buffer(function(bufnr)
            local attach = swift_setup()
            attach(nil, bufnr)
            attach(nil, bufnr)
            local registered = vim.api.nvim_get_autocmds({
                group = "nvim_swift_format_on_save",
                buffer = bufnr,
                event = "BufWritePre",
            })
            expect.equal(#registered, 1, "only one save formatter")
        end)
    end),
    testing.test("native_lsp_bindings_do_not_require_lsp_zero", function()
        local noop = function() end
        local interactions = {
            diagnostics = { jump = function() return noop end },
            diagnostic_copy = {
                copy_current = noop,
                open_float_and_copy = noop,
                copy_buffer = function() return noop end,
            },
            symbol_library = { preview = noop },
        }
        with_buffer(function(bufnr)
            require("integrations.lsp.interaction.bindings")(
                {}, interactions
            )
            vim.api.nvim_exec_autocmds("LspAttach", {
                buffer = bufnr,
                data = { client_id = 1 },
            })
            local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
            local names = {}
            for _, mapping in ipairs(mappings) do
                names[mapping.lhs] = true
            end
            expect.truthy(names.gd, "native definition mapping")
            expect.truthy(names["[d"], "native diagnostic mapping")
        end)
    end),
    testing.test("conform_formatters_are_opt_in_and_exclude_swift", function()
        local old = package.loaded.conform
        local original = vim.g.nvim_tool_format_on_save
        local captured
        local ok, err = pcall(function()
            package.loaded.conform = {
                setup = function(config) captured = config end,
                format = function() end,
            }
            local root = vim.g.nvim_config_test_root
            dofile(vim.fs.joinpath(root, "lua/integrations/formatters.lua"))
            captured = expect.not_nil(captured, "conform setup")
            with_buffer(function(bufnr)
                vim.bo[bufnr].filetype = "lua"
                vim.g.nvim_tool_format_on_save = false
                expect.nil_value(captured.format_on_save(bufnr), "disabled by default")
                vim.g.nvim_tool_format_on_save = true
                expect.not_nil(captured.format_on_save(bufnr), "enabled Lua formatting")
                vim.bo[bufnr].filetype = "swift"
                expect.nil_value(captured.format_on_save(bufnr), "Swift stays independent")
            end)
        end)
        vim.g.nvim_tool_format_on_save = original
        package.loaded.conform = old
        pcall(vim.api.nvim_del_user_command, "ToolFormat")
        pcall(vim.api.nvim_del_user_command, "ToolFormatOnSave")
        if not ok then error(err, 0) end
    end),
    testing.test("nvim_lint_routes_only_selected_filetypes", function()
        local old = package.loaded.lint
        local mock = { linters_by_ft = {}, try_lint = function() end }
        local ok, err = pcall(function()
            package.loaded.lint = mock
            local root = vim.g.nvim_config_test_root
            dofile(vim.fs.joinpath(root, "lua/integrations/linters.lua"))
            expect.equal(expect.not_nil(mock.linters_by_ft.swift)[1], "swiftlint")
            expect.equal(expect.not_nil(mock.linters_by_ft.sh)[1], "shellcheck")
            expect.equal(expect.not_nil(mock.linters_by_ft.bash)[1], "shellcheck")
            expect.nil_value(mock.linters_by_ft.lua, "Lua is not linted here")
        end)
        package.loaded.lint = old
        pcall(vim.api.nvim_del_user_command, "ToolLint")
        if not ok then error(err, 0) end
    end),
}, { title = "LSP and toolchain integration" })
