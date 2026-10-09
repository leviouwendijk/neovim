-- Native LSP configuration must not depend on completion or Mason plugins.
local funcs = require("config.funcs")
local acc = require("accessor")

local cmp_nvim_lsp = funcs.require_or_nil("cmp_nvim_lsp", {
    message = "cmp_nvim_lsp unavailable; using native LSP capabilities",
})
local capabilities = cmp_nvim_lsp
    and cmp_nvim_lsp.default_capabilities()
    or vim.lsp.protocol.make_client_capabilities()

vim.lsp.config("*", { capabilities = capabilities })

local context = {
    funcs = funcs,
    acc = acc,
    capabilities = capabilities,
}
context.swift_attach = require("integrations.lsp.swift")(context)

-- Register attach handlers before enabling any language servers.
require("integrations.lsp.interaction")(context)
require("integrations.lsp.servers")(context)
require("integrations.lsp.semantics")(context)
require("integrations.lsp.ltex")

-- Mason installs/enables additional servers, but cannot gate native servers.
local mason = funcs.require_or_nil("mason", {
    message = "mason unavailable; skipping managed language servers",
})
if mason then
    mason.setup({})
    local mason_lspconfig = funcs.require_or_nil("mason-lspconfig", {
        message = "mason-lspconfig unavailable; skipping managed LSP installation",
    })
    if mason_lspconfig then
        mason_lspconfig.setup({
            ensure_installed = {
                "rust_analyzer", "html", "cssls", "sqlls",
                "texlab", "pyright", "clangd", "lua_ls",
                "vimls", "jsonls", "yamlls", "ltex_plus", "zls",
            },
            -- Mason v2 uses native vim.lsp.enable, not setup handlers.
            automatic_enable = true,
        })
    end
end

-- Completion is optional. Missing cmp should not disable LSP.
local cmp = funcs.require_or_nil("cmp", {
    message = "nvim-cmp unavailable; LSP will work without popup completion",
})
if cmp then
    context.cmp = cmp
    require("integrations.lsp.completion")(context)
end

