return function(context)
    local funcs = context.funcs
    local acc = context.acc
    local capabilities = context.capabilities

    vim.lsp.config("lua_ls", {
        settings = { Lua = {} },
        on_init = function(client)
            local folder = client.workspace_folders and client.workspace_folders[1]
            local path = folder and folder.name or nil
            local uv = vim.uv or vim.loop
            if path and (uv.fs_stat(path .. "/.luarc.json")
                or uv.fs_stat(path .. "/.luarc.jsonc")) then
                return
            end

            client.config.settings.Lua = vim.tbl_deep_extend(
                "force", client.config.settings.Lua or {}, {
                    runtime = { version = "LuaJIT" },
                    workspace = {
                        checkThirdParty = false,
                        library = {
                            vim.env.VIMRUNTIME,
                            "${3rd}/luv/library",
                        },
                    },
                    diagnostics = { globals = { "vim" } },
                    telemetry = { enable = false },
                }
            )
        end,
    })
    vim.lsp.enable("lua_ls")

    -- SourceKit-LSP remains independent of Mason and nvim-cmp.
    local developer_dir = acc.sourcekit and acc.sourcekit.developer_dir
    local sourcekit_cmd = developer_dir
        and { "xcrun", "sourcekit-lsp" }
        or acc.bin.sourcekit
    if funcs.has_executable(sourcekit_cmd) then
        vim.lsp.config("sourcekit", {
            cmd = sourcekit_cmd,
                cmd_env = developer_dir
                    and { DEVELOPER_DIR = developer_dir }
                    or nil,
            filetypes = { "swift" },
            single_file_support = true,
            offset_encoding = "utf-16",
            capabilities = vim.tbl_deep_extend("force", capabilities, {
                general = { positionEncodings = { "utf-16" } },
                workspace = {
                    didChangeWatchedFiles = { dynamicRegistration = true },
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
            }),
            on_attach = context.swift_attach,
        })
        vim.lsp.enable("sourcekit")
    else
        funcs.warn_once(
            "lsp:sourcekit",
            "sourcekit-lsp missing; skipping Swift LSP setup",
            vim.log.levels.WARN
        )
    end

    local function ec_root_dir(bufnr)
        if type(bufnr) ~= "number"
            or not vim.api.nvim_buf_is_valid(bufnr) then
            return nil
        end
        local path = vim.api.nvim_buf_get_name(bufnr)
        if path == "" then return nil end
        local dir = vim.fs.dirname(path)
        local marker = vim.fs.find(
            { "entries", "config" },
            { path = dir, upward = true, type = "directory" }
        )[1]
        return marker and vim.fs.dirname(marker) or nil
    end

    local eclsp_cmd = acc.bin.eclsp
    if funcs.has_executable(eclsp_cmd) then
        vim.lsp.config("eclsp", {
            cmd = eclsp_cmd.production,
            filetypes = { "ec" },
            single_file_support = true,
            root_dir = function(bufnr, on_dir)
                on_dir(ec_root_dir(bufnr))
            end,
            offset_encoding = "utf-16",
            capabilities = vim.tbl_deep_extend("force", capabilities, {
                general = { positionEncodings = { "utf-16" } },
                textDocument = {
                    completion = {
                        completionItem = {
                            snippetSupport = true,
                            commitCharactersSupport = true,
                        },
                        contextSupport = true,
                    },
                },
            }),
        })
        vim.lsp.enable("eclsp")
    else
        funcs.warn_once(
            "lsp:eclsp",
            "eclsp missing; skipping EC LSP setup",
            vim.log.levels.WARN
        )
    end
end

