-- Optional second Swift LSP: authored lint diagnostics only.
return function(context)
    local settings = (context.acc.swiftsemantics or {}).lsp or {}
    if settings.enabled ~= true then return end

    local spec = context.acc.bin.semlsp or { production = { "semlsp" } }
    local cmd = spec.production or spec
    if not context.funcs.has_executable(cmd) then
        context.funcs.warn_once(
            "lsp:semlsp", "semlsp is enabled but not installed; skipping",
            vim.log.levels.WARN
        )
        return
    end

    vim.lsp.config("semlsp", {
        cmd = cmd,
        filetypes = { "swift" },
        root_dir = function(bufnr, on_dir)
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name == "" then return end
            local root = vim.fs.root(bufnr, { "Package.swift", ".git" })
                or vim.fs.dirname(name)
            if root then on_dir(root) end
        end,
        single_file_support = true,
        offset_encoding = "utf-16",
    })
    vim.lsp.enable("semlsp")
end
