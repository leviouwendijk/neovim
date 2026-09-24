local funcs = require("config.funcs")
local acc = require("accessor")

local lsp_zero = funcs.require_or_nil("lsp-zero", {
    message = "lsp-zero missing; skipping LSP setup",
})

local cmp = funcs.require_or_nil("cmp", {
    message = "cmp missing; skipping LSP/cmp setup",
})

local mason = funcs.require_or_nil("mason", {
    message = "mason missing; skipping Mason setup",
})

local mason_lspconfig = funcs.require_or_nil("mason-lspconfig", {
    message = "mason-lspconfig missing; skipping Mason LSP bridge setup",
})

local cmp_nvim_lsp = funcs.require_or_nil("cmp_nvim_lsp", {
    message = "cmp_nvim_lsp missing; skipping LSP capability setup",
})

if not lsp_zero or not cmp or not mason or not mason_lspconfig or not cmp_nvim_lsp then
    return
end

local context = {
    funcs = funcs,
    acc = acc,
    lsp_zero = lsp_zero,
    cmp = cmp,
    mason = mason,
    mason_lspconfig = mason_lspconfig,
    cmp_nvim_lsp = cmp_nvim_lsp,
}

context.swift_attach =
    require("integrations.lsp.swift")(context)

require("integrations.lsp.interaction")(context)
require("integrations.lsp.servers")(context)
require("integrations.lsp.completion")(context)
require("integrations.lsp.ltex")
