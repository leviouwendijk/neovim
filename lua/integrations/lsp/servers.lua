return function(context)
    local funcs = context.funcs
    local acc = context.acc
    local lsp_zero = context.lsp_zero
    local mason = context.mason
    local mason_lspconfig = context.mason_lspconfig
    local cmp_nvim_lsp = context.cmp_nvim_lsp
    local _swift_attach_formatting = context.swift_attach

    mason.setup({})
    mason_lspconfig.setup({
        ensure_installed = {
            --    'tsserver', 
            'rust_analyzer',
            --    'typescript-language-server',  -- TypeScript and JavaScript
            'html',                        -- HTML
            'cssls',                       -- CSS
            'sqlls',                       -- SQL
            'texlab',                      -- LaTeX
            'pyright',                     -- Python
            'clangd',                      -- C
            'lua_ls',                      -- Lua
            'vimls',                       -- VimL (Vim script)
            'jsonls',                      -- JSON
            'yamlls',                      -- YAML
            'ltex_plus',
            'zls'
        },
        handlers = {
            function(server)
                if server == 'lua_ls' or server == 'ltex_plus' then return end
                lsp_zero.default_setup(server)
            end,

            ltex_plus = function() end,  -- <— prevent default_setup from also starting ltex_plus
        }
    })

    -- lua
    vim.lsp.config('lua_ls', {
        on_attach    = lsp_zero.on_attach,
        capabilities = cmp_nvim_lsp.default_capabilities(),
        settings = { Lua = {} },

        on_init = function(client)
            local wf = client.workspace_folders and client.workspace_folders[1]
            local path = wf and wf.name or nil
            local uv   = vim.uv or vim.loop
            if path and (uv.fs_stat(path..'/.luarc.json') or uv.fs_stat(path..'/.luarc.jsonc')) then
                return
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
                runtime = { version = 'LuaJIT' },
                workspace = {
                    checkThirdParty = false,
                    library = {
                        vim.env.VIMRUNTIME, -- or vim.api.nvim_get_runtime_file('', true)
                        "${3rd}/luv/library",  -- lets lua_ls know libuv APIs like fs_stat
                    },
                },
                diagnostics = { globals = { 'vim' } },
                telemetry   = { enable = false },
            }
            )
        end,
    })
    vim.lsp.enable('lua_ls')


    -- Swift SourceKit invocation
    -- using native vim.lsp... api
    -- local XCODE_DEV = '/Applications/Xcode.app/Contents/Developer'
    -- local XCODE_TC  = XCODE_DEV .. '/Toolchains/XcodeDefault.xctoolchain'

    local cmp_caps = cmp_nvim_lsp.default_capabilities()

    -- Defensive: ensure the expected nested tables exist and snippetSupport is true
    cmp_caps.textDocument = cmp_caps.textDocument or {}
    cmp_caps.textDocument.completion = cmp_caps.textDocument.completion or {}
    cmp_caps.textDocument.completion.completionItem = cmp_caps.textDocument.completion.completionItem or {}

    -- Ensure snippet support is enabled (some LSPs need this explicitly)
    cmp_caps.textDocument.completion.completionItem.snippetSupport = true

    -- Optional: also advertise context support — helpful for richer completions
    cmp_caps.textDocument.completion.contextSupport = true

    -- local util = require('lspconfig.util')
    local sourcekit_cmd = acc.bin.sourcekit
    local has_sourcekit = funcs.has_executable(sourcekit_cmd)

    if has_sourcekit then
        -- require('lspconfig').sourcekit.setup({
        vim.lsp.config(
            'sourcekit',
            {
                cmd = sourcekit_cmd,
                -- cmd                  = { XCODE_TC .. '/usr/bin/sourcekit-lsp' }, -- force Xcode toolchain
                -- cmd_env              = {
                --     DEVELOPER_DIR = XCODE_DEV,           -- let the server find frameworks
                --     SOURCEKIT_TOOLCHAIN_PATH = XCODE_TC, -- where SwiftSourceKit*Plugin.framework live
                -- },
                -- -- the environment vars are not strictly necessary, but possibly help resolve faster?
                filetypes            = { 'swift' },
                single_file_support  = true,
                -- root_dir             = swift_root_dir,
                -- root_dir            = util.root_pattern('Package.swift'),
                offset_encoding      = 'utf-16',
                capabilities         = vim.tbl_deep_extend(
                    'force',
                    cmp_caps,
                    {
                        general  = { positionEncodings = { 'utf-16' } },
                        workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
                        -- additions
                        textDocument = {
                            completion = {
                                completionItem = {
                                    snippetSupport = true,
                                    commitCharactersSupport = true,
                                },
                                contextSupport = true,
                            },
                        },
                    }
                ),

                on_attach = function(client, bufnr)
                    _swift_attach_formatting(client, bufnr)
                end,
            }
        )
        vim.lsp.enable('sourcekit')
    else
        funcs.warn_once(
            "lsp:sourcekit",
            "sourcekit-lsp missing; skipping Swift LSP setup",
            vim.log.levels.WARN
        )
    end

    -- Entry Compiler eclsp
    local function ec_root_dir(input)
        local path

        if type(input) == "number" then
            path = vim.api.nvim_buf_get_name(input)
        elseif type(input) == "string" then
            path = input
        else
            return nil
        end

        if path == nil or path == "" then
            return nil
        end

        local dir = vim.fs.dirname(path)
        if not dir or dir == "" then
            return nil
        end

        local root = vim.fs.find(
            { "entries", "config" },
            {
                path = dir,
                upward = true,
                type = "directory",
            }
        )[1]

        if root then
            return vim.fs.dirname(root)
        end

        return nil
    end


    local eclsp_cmd = acc.bin.eclsp
    local has_eclsp = funcs.has_executable(eclsp_cmd)


    if has_eclsp then
        vim.lsp.config(
            'eclsp',
            {
                cmd = eclsp_cmd.production,
                filetypes = { 'ec' },
                single_file_support = true,
                root_dir = function(bufnr, on_dir)
                    on_dir(ec_root_dir(bufnr))
                end,
                offset_encoding = 'utf-16',
                capabilities = vim.tbl_deep_extend(
                    'force',
                    cmp_caps,
                    {
                        general = {
                            positionEncodings = { 'utf-16' },
                        },
                        textDocument = {
                            completion = {
                                completionItem = {
                                    snippetSupport = true,
                                    commitCharactersSupport = true,
                                },
                                contextSupport = true,
                            },
                        },
                    }
                ),
            }
        )
        vim.lsp.enable('eclsp')
    else
        funcs.warn_once(
            "lsp:eclsp",
            "eclsp missing; skipping EC LSP setup",
            vim.log.levels.WARN
        )
    end
end
